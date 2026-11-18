import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/domain/models/learned_pattern.dart';
import 'package:finazaap/features/notifications/domain/models/transaction_classification.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/text_similarity_index.dart';

/// Cabecera compacta en RAM para evitar deserializar registros completos de Hive
/// en cada consulta de búsqueda semántica o selección few-shot.
class _CompactPatternHeader {
  final String merchantKey;
  final String category;
  final String classification;
  final String? accountName;
  final List<String> aliases;
  final List<String> knownPackages;
  final int confirmations;
  final PatternStatus status;
  final DateTime lastUsedAt;

  const _CompactPatternHeader({
    required this.merchantKey,
    required this.category,
    required this.classification,
    required this.accountName,
    required this.aliases,
    required this.knownPackages,
    required this.confirmations,
    required this.status,
    required this.lastUsedAt,
  });

  factory _CompactPatternHeader.fromPattern(LearnedPattern pattern) {
    return _CompactPatternHeader(
      merchantKey: pattern.merchantKey,
      category: pattern.category,
      classification: pattern.classification,
      accountName: pattern.accountName,
      aliases: pattern.aliases,
      knownPackages: pattern.knownPackages,
      confirmations: pattern.confirmations,
      status: pattern.status,
      lastUsedAt: pattern.lastUsedAt,
    );
  }

  static _CompactPatternHeader? tryFromRawMap(
    dynamic fallbackKey,
    Map<dynamic, dynamic> raw,
  ) {
    final merchantKey =
        (raw['merchant_key'] ?? raw['merchantKey'] ?? fallbackKey)?.toString();
    final category = raw['category']?.toString();
    if (merchantKey == null ||
        merchantKey.trim().isEmpty ||
        category == null ||
        category.trim().isEmpty) {
      return null;
    }

    final confirmations = (raw['confirmations'] as num?)?.toInt() ?? 1;
    final rawLastUsed = raw['last_used_at'] ?? raw['lastUsedAt'];
    final lastUsedAt = rawLastUsed is String
        ? (DateTime.tryParse(rawLastUsed) ?? DateTime.now())
        : DateTime.now();
    final correctionStreak =
        (raw['correction_streak'] ?? raw['correctionStreak'] as num?)
                ?.toInt() ??
            0;
    final rawStatus = raw['status'] as String?;
    final status = rawStatus != null
        ? PatternStatus.fromWire(rawStatus)
        : LearnedPattern.computeStatus(
            confirmations: confirmations,
            lastUsedAt: lastUsedAt,
            correctionStreak: correctionStreak,
          );

    List<String> parseStrings(dynamic value) {
      if (value is! Iterable) return const [];
      return List<String>.unmodifiable(
        value
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty),
      );
    }

    return _CompactPatternHeader(
      merchantKey: merchantKey,
      category: category,
      classification: (raw['classification'] as String?) ?? 'gasto',
      accountName: (raw['account_name'] ?? raw['accountName']) as String?,
      aliases: parseStrings(raw['aliases']),
      knownPackages:
          parseStrings(raw['known_packages'] ?? raw['knownPackages']),
      confirmations: confirmations,
      status: status,
      lastUsedAt: lastUsedAt,
    );
  }

  PatternStatus effectiveStatus({DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (reference.difference(lastUsedAt).inDays >
        LearnedPattern.obsoleteAfterDays) {
      return PatternStatus.obsoleto;
    }
    return status;
  }

  CompactSimilarityEntry toSimilarityEntry() {
    return CompactSimilarityEntry(
      key: merchantKey,
      aliases: aliases,
      category: category,
      knownPackages: knownPackages,
      confirmations: confirmations,
    );
  }
}

/// Servicio de almacenamiento local en Hive para patrones aprendidos de comercios.
///
/// Gestiona la caja Hive "learned_patterns" usando serialización Map/JSON sin tocar
/// adaptadores generados (*.g.dart). Mantiene únicamente cabeceras compactas y un
/// índice invertido en RAM para resolver variantes semánticas en `< 1 ms` y leer
/// de disco (`box.get(key)`) solo los ganadores.
class LearnedPatternsService {
  static const String defaultBoxName = 'learned_patterns';

  final Box<dynamic>? _injectedBox;
  final String _boxName;
  final NotificationBoxEncryption? _boxEncryption;

  final Map<String, _CompactPatternHeader> _headers = {};
  final CompactSimilarityIndex _similarityIndex = CompactSimilarityIndex();
  Box<dynamic>? _indexedBox;
  int _indexedBoxLength = -1;
  bool _indexLoaded = false;

  LearnedPatternsService({
    Box<dynamic>? box,
    String boxName = defaultBoxName,
    NotificationBoxEncryption? boxEncryption,
  })  : _injectedBox = box,
        _boxName = boxName,
        _boxEncryption = boxEncryption;

  /// Cantidad de cabeceras compactas actualmente indexadas en RAM.
  int get cachedHeaderCount => _headers.length;

  /// Indica si la caja indexada está confirmadamente vacía tras la última lectura.
  bool get isKnownEmpty =>
      _indexLoaded &&
      _headers.isEmpty &&
      (_indexedBox == null || _indexedBox!.length == 0);

  /// Obtiene la caja Hive abierta (cifrada si [_boxEncryption] está configurado).
  Future<Box<dynamic>> _getBox() async {
    if (_injectedBox != null) {
      return _injectedBox!;
    }
    if (_boxEncryption != null) {
      return _boxEncryption!.openEncryptedBox(_boxName);
    }
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return await Hive.openBox<dynamic>(_boxName);
  }

  void _ensureIndexLoaded(Box<dynamic> box) {
    if (_indexLoaded &&
        identical(_indexedBox, box) &&
        _indexedBoxLength == box.length) {
      return;
    }

    _headers.clear();
    final entries = <CompactSimilarityEntry>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        final header = _CompactPatternHeader.tryFromRawMap(key, raw);
        if (header != null) {
          _headers[header.merchantKey] = header;
          entries.add(header.toSimilarityEntry());
        }
      }
    }

    _similarityIndex.rebuild(entries);
    _indexedBox = box;
    _indexedBoxLength = box.length;
    _indexLoaded = true;
  }

  void _upsertHeader(LearnedPattern pattern, int boxLength) {
    final header = _CompactPatternHeader.fromPattern(pattern);
    _headers[header.merchantKey] = header;
    _similarityIndex.upsert(header.toSimilarityEntry());
    _indexedBoxLength = boxLength;
  }

  void _removeHeader(String key, int boxLength) {
    _headers.remove(key);
    _similarityIndex.remove(key);
    _indexedBoxLength = boxLength;
  }

  static final RegExp _reA = RegExp(r'[áàäâ]');
  static final RegExp _reE = RegExp(r'[éèëê]');
  static final RegExp _reI = RegExp(r'[íìïî]');
  static final RegExp _reO = RegExp(r'[óòöô]');
  static final RegExp _reU = RegExp(r'[úùüû]');
  static final RegExp _reN = RegExp(r'[ñ]');
  static final RegExp _reNonWord = RegExp(r'[^\w\s]');
  static final RegExp _reBranch = RegExp(
    r'\b(sucursal|suc|tienda|store|sede|no)\s*\d+\b',
    caseSensitive: false,
  );
  static final RegExp _reTrailingNumbers = RegExp(r'(?:\s+\d+)+$');
  static final RegExp _reMultiSpace = RegExp(r'\s+');

  /// Normaliza la cadena del comercio:
  /// - Minúsculas
  /// - Sin tildes / diacríticos
  /// - Sin caracteres especiales ni puntuación
  /// - Sin sufijos numéricos de sucursal (ej. '034', '#12', 'suc. 4')
  /// - Espacios colapsados y podados
  static String normalizeMerchant(String merchant) {
    var text = merchant.trim().toLowerCase();
    if (text.isEmpty) return '';

    // 1. Reemplazo de vocales con tildes y diacríticos
    text = text
        .replaceAll(_reA, 'a')
        .replaceAll(_reE, 'e')
        .replaceAll(_reI, 'i')
        .replaceAll(_reO, 'o')
        .replaceAll(_reU, 'u')
        .replaceAll(_reN, 'n');

    // 2. Eliminar puntuación y caracteres especiales no alfanuméricos
    text = text.replaceAll(_reNonWord, ' ');

    // 3. Eliminar sufijos o prefijos explícitos de sucursal / tienda / sede seguidos de número
    text = text.replaceAll(_reBranch, ' ');

    // 4. Eliminar números aislados al final del texto (ej. 'Éxito Laureles 034' -> 'exito laureles')
    // preservando tokens alfanuméricos integrados como 'd1' o '3b'
    final withoutTrailingNumbers =
        text.replaceAll(_reTrailingNumbers, '').trim();
    if (withoutTrailingNumbers.isNotEmpty) {
      text = withoutTrailingNumbers;
    }

    // 5. Colapsar espacios múltiples y recortar bordes
    return text.replaceAll(_reMultiSpace, ' ').trim();
  }

  /// Busca un patrón previamente aprendido por nombre exacto normalizado de comercio.
  Future<LearnedPattern?> findPattern(String merchant) async {
    final key = normalizeMerchant(merchant);
    if (key.isEmpty) return null;

    final box = await _getBox();
    if (box.length == 0) {
      _headers.clear();
      _similarityIndex.clear();
      _indexedBox = box;
      _indexedBoxLength = 0;
      _indexLoaded = true;
      return null;
    }
    final raw = box.get(key);
    if (raw == null) return null;

    if (raw is Map) {
      final pattern = LearnedPattern.fromJson(Map<String, dynamic>.from(raw));
      if (_indexLoaded && identical(_indexedBox, box)) {
        _upsertHeader(pattern, box.length);
      }
      return pattern;
    }
    return null;
  }

  /// Busca semánticamente el patrón aprendido más similar a [query] usando las
  /// cabeceras compactas y el índice invertido en RAM (`< 1 ms`), leyendo de disco
  /// (`box.get(key)`) únicamente el patrón ganador.
  Future<LearnedPattern?> findBestSemanticMatch(
    String query, {
    String? packageName,
    double minScore = 0.88,
    DateTime? now,
  }) async {
    final normalizedQuery = normalizeMerchant(query);
    final effectiveQuery =
        normalizedQuery.isNotEmpty ? normalizedQuery : query.trim();
    if (effectiveQuery.isEmpty) return null;

    final box = await _getBox();
    _ensureIndexLoaded(box);
    if (_headers.isEmpty) return null;

    final matches = _similarityIndex.search(
      effectiveQuery,
      packageName: packageName,
      limit: 8,
      minScore: minScore,
    );
    if (matches.isEmpty) return null;

    for (final match in matches) {
      final header = _headers[match.key];
      if (header == null || header.confirmations < 1) continue;
      final headerStatus = header.effectiveStatus(now: now);
      if (headerStatus == PatternStatus.obsoleto ||
          headerStatus == PatternStatus.enRevision) {
        continue;
      }

      // Leer de disco exclusivamente el ganador validado en cabecera
      final raw = box.get(match.key);
      if (raw is! Map) continue;
      final pattern = LearnedPattern.fromJson(Map<String, dynamic>.from(raw));
      final patternStatus = pattern.effectiveStatus(now: now);
      if (pattern.confirmations < 1 ||
          patternStatus == PatternStatus.obsoleto ||
          patternStatus == PatternStatus.enRevision) {
        continue;
      }
      return pattern;
    }

    return null;
  }

  static String? _cleanOptionalAlias(String? alias, String merchantKey) {
    if (alias == null) return null;
    final trimmed = alias.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == merchantKey.toLowerCase()) return null;
    return trimmed;
  }

  static String? _cleanOptionalPackage(String? packageName) {
    if (packageName == null) return null;
    final trimmed = packageName.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Registra la confirmación de una transacción por el usuario.
  /// Incrementa el contador de confirmaciones y actualiza la última fecha de uso.
  Future<LearnedPattern> recordConfirmation({
    required String merchant,
    required String category,
    String? accountName,
    String classification = 'gasto',
    String? moneoType,
    String? alias,
    String? packageName,
    DateTime? at,
  }) async {
    final key = normalizeMerchant(merchant);
    if (key.isEmpty) {
      throw ArgumentError('El comercio normalizado no puede estar vacío');
    }

    final box = await _getBox();
    final existing = await findPattern(merchant);
    final now = at ?? DateTime.now();
    final resolvedMoneo = moneoType ??
        TransactionClassification.resolveMoneoType(classification) ??
        'Expenses';
    final cleanAlias = _cleanOptionalAlias(alias, key);
    final cleanPkg = _cleanOptionalPackage(packageName);

    final LearnedPattern updated;
    if (existing != null) {
      updated = existing
          .incrementConfirmation(
            at: now,
            confirmedCategory: category,
            confirmedAccountName: accountName,
            alias: cleanAlias,
            packageName: cleanPkg,
          )
          .copyWith(
            classification: classification,
            moneoType: resolvedMoneo,
          );
    } else {
      updated = LearnedPattern(
        merchantKey: key,
        category: category,
        accountName: accountName,
        classification: classification,
        moneoType: resolvedMoneo,
        confirmations: 1,
        createdAt: now,
        lastUsedAt: now,
        aliases: cleanAlias != null ? [cleanAlias] : const [],
        knownPackages: cleanPkg != null ? [cleanPkg] : const [],
      );
    }

    await box.put(key, updated.toJson());
    if (_indexLoaded && identical(_indexedBox, box)) {
      _upsertHeader(updated, box.length);
    }
    return updated;
  }

  /// Registra una corrección explícita del usuario sobre un comercio.
  /// Sobrescribe la categoría/cuenta, fija confirmations en 1 y actualiza lastCorrectedAt.
  Future<LearnedPattern> recordCorrection({
    required String merchant,
    required String newCategory,
    String? newAccountName,
    String? newClassification,
    String? newMoneoType,
    String? alias,
    String? packageName,
    DateTime? at,
  }) async {
    final key = normalizeMerchant(merchant);
    if (key.isEmpty) {
      throw ArgumentError('El comercio normalizado no puede estar vacío');
    }

    final box = await _getBox();
    final existing = await findPattern(merchant);
    final now = at ?? DateTime.now();
    final classification =
        newClassification ?? existing?.classification ?? 'gasto';
    final resolvedMoneo = newMoneoType ??
        TransactionClassification.resolveMoneoType(classification) ??
        'Expenses';
    final cleanAlias = _cleanOptionalAlias(alias, key);
    final cleanPkg = _cleanOptionalPackage(packageName);

    final LearnedPattern updated;
    if (existing != null) {
      updated = existing.applyCorrection(
        newCategory: newCategory,
        newAccountName: newAccountName,
        newClassification: classification,
        newMoneoType: resolvedMoneo,
        alias: cleanAlias,
        packageName: cleanPkg,
        at: now,
      );
    } else {
      updated = LearnedPattern(
        merchantKey: key,
        category: newCategory,
        accountName: newAccountName,
        classification: classification,
        moneoType: resolvedMoneo,
        confirmations: 1,
        createdAt: now,
        lastUsedAt: now,
        lastCorrectedAt: now,
        aliases: cleanAlias != null ? [cleanAlias] : const [],
        knownPackages: cleanPkg != null ? [cleanPkg] : const [],
      );
    }

    await box.put(key, updated.toJson());
    if (_indexLoaded && identical(_indexedBox, box)) {
      _upsertHeader(updated, box.length);
    }
    return updated;
  }

  /// Elimina un patrón aprendido por clave de comercio.
  Future<void> deletePattern(String merchant) async {
    final key = normalizeMerchant(merchant);
    if (key.isEmpty) return;

    final box = await _getBox();
    await box.delete(key);
    if (_indexLoaded && identical(_indexedBox, box)) {
      _removeHeader(key, box.length);
    }
  }

  /// Obtiene todos los patrones aprendidos almacenados.
  Future<List<LearnedPattern>> getAllPatterns() async {
    final box = await _getBox();
    final patterns = <LearnedPattern>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        patterns.add(LearnedPattern.fromJson(Map<String, dynamic>.from(raw)));
      }
    }
    return patterns;
  }

  /// Obtiene ejemplos compactos (few-shot) desde patrones validados por el usuario
  /// para asistir a Gemma sin exponer texto crudo ni datos sensibles innecesarios.
  ///
  /// Selecciona los top-[limit] ejemplos desde cabeceras en RAM y el índice invertido
  /// en `< 1 ms` sin deserializar toda la caja Hive.
  Future<List<String>> getFewShotExamples({
    int limit = 3,
    String? query,
    DateTime? now,
  }) async {
    if (limit <= 0) return const [];
    final box = await _getBox();
    _ensureIndexLoaded(box);
    if (_headers.isEmpty) return const [];

    final activeHeaders = _headers.values
        .where((h) => h.effectiveStatus(now: now) != PatternStatus.obsoleto)
        .toList();
    if (activeHeaders.isEmpty) return const [];

    final List<_CompactPatternHeader> selected;
    if (query != null && query.trim().isNotEmpty) {
      final hits = _similarityIndex.search(
        query,
        limit: limit * 2,
        minScore: 0.05,
      );
      final matched = <_CompactPatternHeader>[];
      for (final hit in hits) {
        final header = _headers[hit.key];
        if (header != null &&
            header.effectiveStatus(now: now) != PatternStatus.obsoleto) {
          matched.add(header);
          if (matched.length >= limit) break;
        }
      }
      if (matched.isNotEmpty) {
        selected = matched;
      } else {
        activeHeaders.sort((a, b) => b.confirmations.compareTo(a.confirmations));
        selected = activeHeaders.take(limit).toList();
      }
    } else {
      activeHeaders.sort((a, b) => b.confirmations.compareTo(a.confirmations));
      selected = activeHeaders.take(limit).toList();
    }

    return selected
        .map((p) =>
            'comercio="${p.merchantKey}" -> classification="${p.classification}", category="${p.category}"')
        .toList();
  }

  /// Poda patrones obsoletos (>180 días sin uso) y compacta la caja Hive.
  Future<int> pruneObsoletePatterns({
    DateTime? now,
    Duration maxInactivity =
        const Duration(days: LearnedPattern.obsoleteAfterDays),
  }) async {
    final box = await _getBox();
    if (box.length == 0) {
      _headers.clear();
      _similarityIndex.clear();
      _indexedBox = box;
      _indexedBoxLength = 0;
      _indexLoaded = true;
      return 0;
    }
    final reference = now ?? DateTime.now();
    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        try {
          final pattern =
              LearnedPattern.fromJson(Map<String, dynamic>.from(raw));
          if (reference.difference(pattern.lastUsedAt) > maxInactivity) {
            keysToDelete.add(key);
          }
        } catch (_) {
          keysToDelete.add(key);
        }
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
      if (_indexLoaded && identical(_indexedBox, box) && key is String) {
        _removeHeader(key, box.length);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await box.compact();
    }
    if (_indexLoaded && identical(_indexedBox, box)) {
      _indexedBoxLength = box.length;
    }
    return keysToDelete.length;
  }

  /// Limpia todos los patrones aprendidos en la caja.
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
    _headers.clear();
    _similarityIndex.clear();
    _indexedBox = box;
    _indexedBoxLength = 0;
    _indexLoaded = true;
  }
}
