import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/domain/models/spam_models.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/text_similarity_index.dart';

/// Servicio local de aprendizaje negativo (patrones de Spam / promociones descartadas).
///
/// Gestiona la caja Hive cifrada `dismissed_patterns` y un índice invertido ligero
/// en RAM (`< 1 ms`) para bloquear promos/ruido recurrentes SIN invocar a la IA
/// hasta que el usuario indique explícitamente "No es spam" desde la pestaña Spam.
class SpamPatternsService {
  static const String defaultBoxName = 'dismissed_patterns';

  static final RegExp _currencyAndNumbersRegex = RegExp(
    r'(?:\$|cop|usd|eur|mxn|pen|gbp)?\s*\d+(?:[.,]\d+)*%?',
    caseSensitive: false,
  );
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');

  /// Canales conocidos de marketing/promociones que pueden bloquearse rápido
  /// cuando el usuario descarta avisos de ese canal en una app híbrida.
  static final RegExp _promoChannelRegex = RegExp(
    r'(promo|marketing|offer|oferta|campaign|campana|news|novedad|deal|coupon|cupon|ads)',
    caseSensitive: false,
  );

  final Box<dynamic>? _injectedBox;
  final String _boxName;
  final NotificationBoxEncryption? _boxEncryption;

  final Map<String, DismissedPattern> _patterns = {};
  final CompactSimilarityIndex _index = CompactSimilarityIndex();
  Box<dynamic>? _indexedBox;
  int _indexedBoxLength = -1;
  bool _indexLoaded = false;

  SpamPatternsService({
    Box<dynamic>? box,
    String boxName = defaultBoxName,
    NotificationBoxEncryption? boxEncryption,
  })  : _injectedBox = box,
        _boxName = boxName,
        _boxEncryption = boxEncryption;

  Future<Box<dynamic>> _getBox() async {
    if (_injectedBox != null) return _injectedBox!;
    if (_boxEncryption != null) {
      return _boxEncryption!.openEncryptedBox(_boxName);
    }
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return Hive.openBox<dynamic>(_boxName);
  }

  void _ensureIndexLoaded(Box<dynamic> box) {
    if (_indexLoaded &&
        identical(_indexedBox, box) &&
        _indexedBoxLength == box.length) {
      return;
    }

    _patterns.clear();
    final entries = <CompactSimilarityEntry>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        try {
          final pattern =
              DismissedPattern.fromJson(Map<String, dynamic>.from(raw));
          _patterns[pattern.signatureKey] = pattern;
          if (pattern.isActive && pattern.templateText.isNotEmpty) {
            entries.add(_toSimilarityEntry(pattern));
          }
        } catch (_) {
          // Ignora entradas corruptas
        }
      }
    }
    _index.rebuild(entries);
    _indexedBox = box;
    _indexedBoxLength = box.length;
    _indexLoaded = true;
  }

  CompactSimilarityEntry _toSimilarityEntry(DismissedPattern p) {
    return CompactSimilarityEntry(
      key: p.signatureKey,
      aliases: [p.templateText],
      knownPackages: p.packageName.isNotEmpty ? [p.packageName] : const [],
      confirmations: p.confirmations,
    );
  }

  void _syncPatternInMemory(DismissedPattern pattern, int boxLength) {
    _patterns[pattern.signatureKey] = pattern;
    if (pattern.isActive && pattern.templateText.isNotEmpty) {
      _index.upsert(_toSimilarityEntry(pattern));
    } else {
      _index.remove(pattern.signatureKey);
    }
    _indexedBoxLength = boxLength;
  }

  /// Normaliza una notificación en una plantilla textual invariante a montos,
  /// porcentajes y números cambiantes (ej. `"Tienes $15.000 de descuento"` → `"tienes de descuento"`).
  static String buildTemplateText(String rawText) {
    final stripped = rawText.replaceAll(_currencyAndNumbersRegex, ' ');
    final norm = TextSimilarityIndex.normalize(stripped);
    return norm.replaceAll(_multiSpaceRegex, ' ').trim();
  }

  /// Construye la clave determinista de un patrón de spam por paquete + plantilla.
  static String buildSignatureKey({
    required String packageName,
    required String rawText,
  }) {
    final pkg = packageName.trim().toLowerCase();
    final template = buildTemplateText(rawText);
    final seed = '$pkg|$template';
    final digest = sha256.convert(utf8.encode(seed)).toString();
    return 'spam_${digest.substring(0, 16)}';
  }

  /// Evalúa en `< 1 ms` si la notificación coincide con un patrón de spam activo
  /// aprendido por el usuario (atajo 0-IA: evita gastar API o cargar Gemma).
  Future<SpamMatchResult?> matchSpam({
    required String packageName,
    required String rawText,
    String? channelId,
    double minScore = 0.80,
  }) async {
    final box = await _getBox();
    _ensureIndexLoaded(box);
    if (_patterns.isEmpty) return null;

    final pkgLower = packageName.trim().toLowerCase();
    final template = buildTemplateText(rawText);
    final cleanChannel = channelId?.trim().toLowerCase() ?? '';

    // 1. Coincidencia exacta de firma (mismo paquete + misma plantilla sin montos)
    final exactKey = buildSignatureKey(packageName: pkgLower, rawText: rawText);
    final exact = _patterns[exactKey];
    if (exact != null && exact.isActive) {
      return SpamMatchResult(pattern: exact, score: 1.0);
    }

    // 2. Canal promocional consolidado del mismo paquete (ej. canal de promos de Rappi)
    if (cleanChannel.isNotEmpty &&
        pkgLower.isNotEmpty &&
        _promoChannelRegex.hasMatch(cleanChannel)) {
      for (final p in _patterns.values) {
        if (!p.isActive) continue;
        if (p.packageName.toLowerCase() == pkgLower &&
            (p.channelId?.toLowerCase() ?? '') == cleanChannel &&
            p.confirmations >= 1) {
          return SpamMatchResult(
            pattern: p,
            score: 0.95,
            matchedByChannel: true,
          );
        }
      }
    }

    // 3. Búsqueda semántica rápida sobre plantillas de spam del mismo paquete
    if (template.isEmpty) return null;
    final hits = _index.search(
      template,
      packageName: pkgLower,
      limit: 6,
      minScore: minScore,
    );
    for (final hit in hits) {
      final candidate = _patterns[hit.key];
      if (candidate == null || !candidate.isActive) continue;
      if (pkgLower.isNotEmpty &&
          candidate.packageName.isNotEmpty &&
          candidate.packageName.toLowerCase() != pkgLower) {
        continue;
      }
      // Verificar que la similitud textual pura sea alta para evitar falsos positivos
      final textSim = TextSimilarityIndex.combinedSimilarity(
        template,
        candidate.templateText,
      );
      if (textSim >= 0.72) {
        return SpamMatchResult(pattern: candidate, score: hit.score);
      }
    }
    return null;
  }

  /// Registra un descarte del usuario (desde Pendientes) o reconfirmación desde Spam.
  Future<DismissedPattern?> recordDismissal({
    required String packageName,
    required String rawText,
    String? channelId,
    bool forceConsolidate = false,
    DateTime? at,
  }) async {
    final template = buildTemplateText(rawText);
    if (template.isEmpty) return null;

    final pkgLower = packageName.trim().toLowerCase();
    final key = buildSignatureKey(packageName: pkgLower, rawText: rawText);
    final box = await _getBox();
    _ensureIndexLoaded(box);
    final now = at ?? DateTime.now();

    final existing = _patterns[key];
    final DismissedPattern updated;
    if (existing != null) {
      final reinforced = existing.reinforce(at: now, newChannelId: channelId);
      updated = forceConsolidate
          ? DismissedPattern(
              signatureKey: reinforced.signatureKey,
              packageName: reinforced.packageName,
              channelId: reinforced.channelId,
              templateText: reinforced.templateText,
              confirmations: reinforced.confirmations <
                      DismissedPattern.consolidatedThreshold
                  ? DismissedPattern.consolidatedThreshold
                  : reinforced.confirmations,
              rescuedCount: reinforced.rescuedCount,
              status: SpamPatternStatus.consolidado,
              createdAt: reinforced.createdAt,
              lastSeenAt: now,
            )
          : reinforced;
    } else {
      updated = DismissedPattern(
        signatureKey: key,
        packageName: pkgLower,
        channelId:
            (channelId != null && channelId.trim().isNotEmpty) ? channelId.trim() : null,
        templateText: template,
        confirmations: forceConsolidate ? 2 : 1,
        status: forceConsolidate
            ? SpamPatternStatus.consolidado
            : SpamPatternStatus.activo,
        createdAt: now,
        lastSeenAt: now,
      );
    }

    await box.put(key, updated.toJson());
    _syncPatternInMemory(updated, box.length);
    return updated;
  }

  /// Cuando el usuario pulsa "No es spam" desde la pestaña Spam:
  /// desactiva la regla que atrapó la notificación para evitar falsos positivos futuros.
  Future<void> rescueFromSpam({
    String? matchedRuleKey,
    required String packageName,
    required String rawText,
    DateTime? at,
  }) async {
    final box = await _getBox();
    _ensureIndexLoaded(box);
    final now = at ?? DateTime.now();

    final keysToDisable = <String>{};
    if (matchedRuleKey != null && _patterns.containsKey(matchedRuleKey)) {
      keysToDisable.add(matchedRuleKey);
    }

    final exactKey = buildSignatureKey(packageName: packageName, rawText: rawText);
    if (_patterns.containsKey(exactKey)) {
      keysToDisable.add(exactKey);
    }

    final match = await matchSpam(
      packageName: packageName,
      rawText: rawText,
      minScore: 0.78,
    );
    if (match != null) {
      keysToDisable.add(match.pattern.signatureKey);
    }

    for (final key in keysToDisable) {
      final existing = _patterns[key];
      if (existing == null) continue;
      final disabled = existing.markRescued(at: now);
      await box.put(key, disabled.toJson());
      _syncPatternInMemory(disabled, box.length);
    }
  }

  /// Devuelve hasta [limit] ejemplos compactos de spam de la misma app para
  /// inyectarlos como ejemplos negativos en el prompt de la IA (budget acotado).
  Future<List<String>> getTopSpamExamples({
    String? packageName,
    String? query,
    int limit = 2,
  }) async {
    if (limit <= 0) return const [];
    final box = await _getBox();
    _ensureIndexLoaded(box);
    final pkgLower = packageName?.trim().toLowerCase() ?? '';

    final active = _patterns.values.where((p) {
      if (!p.isActive || p.templateText.isEmpty) return false;
      if (pkgLower.isNotEmpty &&
          p.packageName.isNotEmpty &&
          p.packageName.toLowerCase() != pkgLower) {
        return false;
      }
      return true;
    }).toList();

    if (active.isEmpty) return const [];

    if (query != null && query.trim().isNotEmpty) {
      final templateQuery = buildTemplateText(query);
      if (templateQuery.isNotEmpty) {
        final hits = _index.search(
          templateQuery,
          packageName: pkgLower,
          limit: limit * 2,
          minScore: 0.05,
        );
        final selected = <DismissedPattern>[];
        for (final hit in hits) {
          final p = _patterns[hit.key];
          if (p != null &&
              p.isActive &&
              (pkgLower.isEmpty ||
                  p.packageName.isEmpty ||
                  p.packageName.toLowerCase() == pkgLower)) {
            selected.add(p);
            if (selected.length >= limit) break;
          }
        }
        if (selected.isNotEmpty) {
          return selected.map(_formatCompactExample).toList();
        }
      }
    }

    active.sort((a, b) => b.confirmations.compareTo(a.confirmations));
    return active.take(limit).map(_formatCompactExample).toList();
  }

  String _formatCompactExample(DismissedPattern p) {
    final text = p.templateText.length > 65
        ? '${p.templateText.substring(0, 65)}...'
        : p.templateText;
    final ch = (p.channelId != null && p.channelId!.isNotEmpty)
        ? ' [canal:${p.channelId}]'
        : '';
    return '"$text"$ch -> SPAM';
  }

  Future<List<DismissedPattern>> getAllPatterns() async {
    final box = await _getBox();
    _ensureIndexLoaded(box);
    return _patterns.values.toList(growable: false);
  }

  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
    _patterns.clear();
    _index.clear();
    _indexedBox = box;
    _indexedBoxLength = 0;
    _indexLoaded = true;
  }
}
