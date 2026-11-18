import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/domain/models/dedup_models.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/text_similarity_index.dart';

/// Motor de deduplicación y correlación de notificaciones ANTES de crear movimientos.
///
/// Pipeline estricto:
/// `normalizar -> blocking -> matching (pendientes + anillo 48h confirmados) -> agrupar -> proponer 1 movimiento -> usuario confirma/separa`.
class TransactionDedupCorrelator {
  static const String defaultRulesBoxName = 'notification_dedup_rules';
  static const String defaultRecentMovementsBoxName =
      'notification_recent_movements';
  static const double probabilisticSimilarityThreshold = 0.90;
  static const Duration correlationWindow = Duration(hours: 48);
  static const Duration recentMovementsTtl = Duration(hours: 48);
  static const Duration lateDuplicateWindow = Duration(minutes: 60);
  static const int maxRecentMovements = 100;

  static final RegExp _referenceRegex = RegExp(
    r'\b(?:utr|ref(?:erencia)?|comprobante|aprob(?:acion|ación)?|autorizacion|autorizaci[oó]n|cus)\b[:\s#-]*([a-z0-9]{4,24})\b',
    caseSensitive: false,
  );

  final Box<dynamic>? _injectedRulesBox;
  final Box<dynamic>? _injectedRecentBox;
  final NotificationBoxEncryption? _boxEncryption;
  final Map<String, DedupRule> _memoryRules = {};
  final Map<String, RecentMovementRecord> _memoryRecentMovements = {};
  bool _recentLoadedFromBox = false;

  TransactionDedupCorrelator({
    Box<dynamic>? rulesBox,
    Box<dynamic>? recentMovementsBox,
    NotificationBoxEncryption? boxEncryption,
  })  : _injectedRulesBox = rulesBox,
        _injectedRecentBox = recentMovementsBox,
        _boxEncryption = boxEncryption;

  Future<Box<dynamic>?> _getRulesBox() async {
    if (_injectedRulesBox != null) {
      return _injectedRulesBox!.isOpen ? _injectedRulesBox : null;
    }
    if (_boxEncryption != null) {
      return _boxEncryption!.openEncryptedBox(defaultRulesBoxName);
    }
    if (Hive.isBoxOpen(defaultRulesBoxName)) {
      return Hive.box<dynamic>(defaultRulesBoxName);
    }
    return null;
  }

  Future<Box<dynamic>?> _getRecentMovementsBox() async {
    if (_injectedRecentBox != null) {
      return _injectedRecentBox!.isOpen ? _injectedRecentBox : null;
    }
    if (_boxEncryption != null) {
      return _boxEncryption!.openEncryptedBox(defaultRecentMovementsBoxName);
    }
    if (Hive.isBoxOpen(defaultRecentMovementsBoxName)) {
      return Hive.box<dynamic>(defaultRecentMovementsBoxName);
    }
    return null;
  }

  /// Extrae un identificador de referencia único (UTR/Ref/Comprobante/CUS) si existe.
  static String? extractReferenceId(String rawText) {
    final match = _referenceRegex.firstMatch(rawText);
    if (match == null) return null;
    final ref = match.group(1)?.trim().toUpperCase();
    if (ref == null || ref.length < 4) return null;
    return ref;
  }

  /// Infiere el canal de la notificación (`app`, `sms`, `correo`).
  static NotificationChannel inferChannel({
    String? packageName,
    String? rawText,
    String? explicitChannel,
  }) {
    if (explicitChannel != null && explicitChannel.isNotEmpty) {
      return NotificationChannel.fromWire(explicitChannel);
    }
    final pkg = (packageName ?? '').toLowerCase();
    final text = (rawText ?? '').toLowerCase();
    if (pkg.contains('sms') ||
        pkg.contains('messaging') ||
        pkg.contains('messages') ||
        pkg.contains('mms') ||
        text.startsWith('sms:')) {
      return NotificationChannel.sms;
    }
    if (pkg == 'com.google.android.gm' ||
        pkg.endsWith('.gm') ||
        pkg.contains('gmail') ||
        pkg.contains('mail') ||
        pkg.contains('outlook') ||
        text.startsWith('correo:')) {
      return NotificationChannel.correo;
    }
    return NotificationChannel.app;
  }

  /// Normaliza un [PendingTransactionItem] a [NormalizedNotificationMovement].
  NormalizedNotificationMovement normalizeItem(
    PendingTransactionItem item, {
    String? packageName,
  }) {
    final resolvedPkg = (packageName != null && packageName.trim().isNotEmpty)
        ? packageName.trim()
        : (item.packageName ?? '').trim();
    final merchantSource = item.comercio ?? item.merchantKey ?? '';
    final normalizedMerchant =
        LearnedPatternsService.normalizeMerchant(merchantSource);
    final amount = item.monto ?? 0.0;
    final refId = item.referenceId ?? extractReferenceId(item.rawText);
    final channel = inferChannel(
      packageName: resolvedPkg,
      rawText: item.rawText,
      explicitChannel: item.channel,
    );

    final String type;
    switch (item.classification) {
      case 'gasto':
        type = 'debito';
        break;
      case 'ingreso':
        type = 'credito';
        break;
      case 'transferencia-propia':
        type = 'transferencia';
        break;
      default:
        type = 'desconocido';
    }

    return NormalizedNotificationMovement(
      id: item.id,
      amount: amount,
      roundedAmount: amount.round(),
      currency: item.moneda,
      timestamp: item.fecha,
      dateKey: NormalizedNotificationMovement.formatDateKey(item.fecha),
      normalizedMerchant: normalizedMerchant,
      merchantHash:
          NormalizedNotificationMovement.computeMerchantHash(normalizedMerchant),
      type: type,
      inferredAccount: item.accountName,
      destinationAccount: item.destinationAccount,
      channel: channel,
      referenceId: refId,
      rawText: item.rawText,
      packageName: resolvedPkg,
    );
  }

  Set<String> _extractPackages(PendingTransactionItem item) {
    final result = <String>{};
    final mainPkg = item.packageName?.trim() ?? '';
    if (mainPkg.isNotEmpty) result.add(mainPkg);
    for (final ev in item.groupedEvents) {
      final pkg = ((ev['package_name'] ?? ev['packageName']) as String?)?.trim();
      if (pkg != null && pkg.isNotEmpty) {
        result.add(pkg);
      }
    }
    return result;
  }

  Set<String> _extractChannels(PendingTransactionItem item) {
    final result = <String>{};
    if (item.channel.trim().isNotEmpty) {
      result.add(item.channel.trim());
    }
    for (final ev in item.groupedEvents) {
      final ch = (ev['channel'] as String?)?.trim();
      if (ch != null && ch.isNotEmpty) {
        result.add(ch);
      }
    }
    return result;
  }

  Future<List<DedupRule>> _loadAllRules() async {
    final box = await _getRulesBox();
    if (box != null) {
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          try {
            final rule = DedupRule.fromJson(Map<String, dynamic>.from(raw));
            _memoryRules[rule.merchantKey] = rule;
          } catch (_) {
            // Ignora entradas corruptas
          }
        }
      }
    }
    return _memoryRules.values.toList(growable: false);
  }

  Future<void> _ensureRecentLoaded() async {
    if (_recentLoadedFromBox) return;
    final box = await _getRecentMovementsBox();
    if (box != null) {
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          try {
            final record =
                RecentMovementRecord.fromJson(Map<String, dynamic>.from(raw));
            _memoryRecentMovements[record.id] = record;
          } catch (_) {
            // Ignora entradas corruptas
          }
        }
      }
    }
    _recentLoadedFromBox = true;
  }

  /// Registra un movimiento recién confirmado o corregido en el anillo de 48 h
  /// (máx. [maxRecentMovements] = 100 entradas) persistido en `notification_recent_movements`.
  Future<void> recordConfirmedMovement(
    RecentMovementRecord record, {
    DateTime? now,
  }) async {
    await _ensureRecentLoaded();
    final reference = now ?? DateTime.now();
    final effectiveRecord = record.recordedAt != null
        ? record
        : record.copyWith(recordedAt: reference);

    _memoryRecentMovements[effectiveRecord.id] = effectiveRecord;
    final box = await _getRecentMovementsBox();
    if (box != null) {
      await box.put(effectiveRecord.id, effectiveRecord.toJson());
    }
    await pruneRecentMovements(now: reference);
  }

  /// Conveniencia para registrar un [PendingTransactionItem] confirmado/corregido.
  Future<void> recordConfirmedItem(
    PendingTransactionItem item, {
    DateTime? at,
    double? overrideAmount,
    String? overrideAccountName,
    String? overrideDestinationAccount,
    DateTime? overrideDate,
  }) async {
    final amount = overrideAmount ?? item.monto ?? 0.0;
    if (amount <= 0) return;

    final reference = at ?? DateTime.now();
    final packages = _extractPackages(item).toList();
    final merchantRaw = item.merchantKey ?? item.comercio ?? '';
    final normalizedMerchant =
        LearnedPatternsService.normalizeMerchant(merchantRaw);
    final refId = item.referenceId ?? extractReferenceId(item.rawText);

    final record = RecentMovementRecord(
      id: item.id,
      amount: amount,
      roundedAmount: amount.round(),
      timestamp: overrideDate ?? item.fecha,
      recordedAt: reference,
      accountName: overrideAccountName ?? item.accountName,
      destinationAccount: overrideDestinationAccount ?? item.destinationAccount,
      referenceId: refId,
      merchantKey: normalizedMerchant.isNotEmpty ? normalizedMerchant : null,
      packageName: item.packageName ??
          (packages.isNotEmpty ? packages.first : null),
      channel: item.channel,
      packages: packages,
    );

    await recordConfirmedMovement(record, now: reference);
  }

  /// Retorna los movimientos vigentes en el anillo de 48 h (podando expirados).
  Future<List<RecentMovementRecord>> getRecentMovements({DateTime? now}) async {
    await _ensureRecentLoaded();
    await pruneRecentMovements(now: now);
    final list = _memoryRecentMovements.values.toList()
      ..sort((a, b) =>
          (b.recordedAt ?? b.timestamp).compareTo(a.recordedAt ?? a.timestamp));
    return list;
  }

  /// Poda movimientos mayores a 48 h y mantiene un tope de [maxRecentMovements] (100).
  Future<int> pruneRecentMovements({DateTime? now}) async {
    await _ensureRecentLoaded();
    final reference = now ?? DateTime.now();
    final keysToDelete = <String>[];
    final surviving = <RecentMovementRecord>[];

    for (final record in _memoryRecentMovements.values) {
      final anchor = record.recordedAt ?? record.timestamp;
      if (reference.difference(anchor) > recentMovementsTtl) {
        keysToDelete.add(record.id);
      } else {
        surviving.add(record);
      }
    }

    if (surviving.length > maxRecentMovements) {
      surviving.sort((a, b) =>
          (b.recordedAt ?? b.timestamp).compareTo(a.recordedAt ?? a.timestamp));
      for (final overflow in surviving.skip(maxRecentMovements)) {
        keysToDelete.add(overflow.id);
      }
    }

    for (final key in keysToDelete) {
      _memoryRecentMovements.remove(key);
    }

    final box = await _getRecentMovementsBox();
    if (box != null) {
      for (final key in keysToDelete) {
        await box.delete(key);
      }
      if (keysToDelete.isNotEmpty) {
        await box.compact();
      }
    }
    return keysToDelete.length;
  }

  DedupRule? _findMultiAppRule({
    required List<DedupRule> allRules,
    required String candPkg,
    required String candChannel,
    required String candMerchant,
    required Set<String> targetPackages,
    required Set<String> targetChannels,
    required String targetMerchant,
  }) {
    for (final rule in allRules) {
      if (!rule.isMultiApp) continue;

      if (candPkg.isNotEmpty && targetPackages.isNotEmpty) {
        final hasCandPkg = rule.packages.contains(candPkg);
        final hasOtherTargetPkg = targetPackages
            .any((p) => p != candPkg && rule.packages.contains(p));
        if (hasCandPkg && hasOtherTargetPkg) {
          return rule;
        }
      }

      // Fallback para pruebas/eventos sin packageName que usan canales distintos
      // junto con al menos un comercio compatible con la regla.
      final hasDifferentChannel =
          targetChannels.any((c) => c != candChannel && rule.channels.contains(c));
      if (rule.channels.contains(candChannel) && hasDifferentChannel) {
        final merchantMatches = (candMerchant.isNotEmpty &&
                rule.merchantKey == candMerchant) ||
            (targetMerchant.isNotEmpty && rule.merchantKey == targetMerchant) ||
            (candMerchant.isNotEmpty &&
                targetMerchant.isNotEmpty &&
                TextSimilarityIndex.combinedSimilarity(
                        candMerchant, targetMerchant) >=
                    0.70);
        if (merchantMatches) {
          return rule;
        }
      }
    }
    return null;
  }

  /// Evalúa un candidato entrante contra la lista de ítems pendientes existentes
  /// y el anillo de 48 h de movimientos confirmados ANTES de crear un nuevo movimiento.
  Future<CorrelationResult> correlate({
    required PendingTransactionItem candidate,
    required List<PendingTransactionItem> existingPending,
    String? packageName,
    DateTime? now,
  }) async {
    if (candidate.monto == null ||
        candidate.monto! <= 0 ||
        candidate.classification == 'sospechosa') {
      return const CorrelationResult(
        decision: CorrelationDecisionType.unique,
        reason: 'Sin monto válido o clasificado como sospechosa',
      );
    }

    final normCandidate = normalizeItem(candidate, packageName: packageName);
    final allRules = await _loadAllRules();

    if (existingPending.isNotEmpty) {
      // Fase 1: Blocking por monto redondeado y ventana temporal (48h)
      final normalizedExisting = existingPending
          .where((e) =>
              e.id != candidate.id &&
              e.monto != null &&
              e.classification != 'sospechosa')
          .map((e) => (item: e, norm: normalizeItem(e)))
          .toList();

      final blockingByKey = <String,
          List<({PendingTransactionItem item, NormalizedNotificationMovement norm})>>{};
      final blockingByAmount = <int,
          List<({PendingTransactionItem item, NormalizedNotificationMovement norm})>>{};

      for (final entry in normalizedExisting) {
        blockingByKey.putIfAbsent(entry.norm.blockingKey, () => []).add(entry);
        blockingByAmount
            .putIfAbsent(entry.norm.roundedAmount, () => [])
            .add(entry);
      }

      // Fase 2A: Matching determinista por ID único (UTR / referenceId)
      if (normCandidate.referenceId != null) {
        for (final entry in normalizedExisting) {
          final existingRef = entry.norm.referenceId;
          if (existingRef != null &&
              existingRef == normCandidate.referenceId) {
            final transferPair = _tryInternalTransferPair(
              candidate: normCandidate,
              existing: entry.norm,
            );
            if (transferPair != null) return transferPair;

            if ((normCandidate.amount - entry.norm.amount).abs() < 0.01) {
              return CorrelationResult(
                decision: CorrelationDecisionType.exactDuplicate,
                matchedPendingItemId: entry.item.id,
                similarityScore: 1.0,
                reason:
                    'Coincidencia determinista por referencia ${normCandidate.referenceId}',
              );
            }
          }
        }
      }

      final amountBucket =
          blockingByAmount[normCandidate.roundedAmount] ?? const [];

      if (amountBucket.isNotEmpty) {
        // Fase 2B: Correlación de transferencia interna (débito en A + crédito en B)
        for (final entry in amountBucket) {
          final transferPair = _tryInternalTransferPair(
            candidate: normCandidate,
            existing: entry.norm,
          );
          if (transferPair != null) {
            return transferPair;
          }
        }

        // Fase 2C: Matching multi-app aprendido por (packages, monto exacto, <= 60m)
        // y matching probabilístico (monto exacto + ventana 48h + similitud >= 0.90)
        final sameKeyBucket =
            blockingByKey[normCandidate.blockingKey] ?? const [];
        final searchPool = <({
          PendingTransactionItem item,
          NormalizedNotificationMovement norm
        })>{
          ...sameKeyBucket,
          ...amountBucket,
        }.toList();

        for (final entry in searchPool) {
          final existing = entry.norm;
          if ((normCandidate.amount - existing.amount).abs() >= 0.01) continue;

          // Si ambos traen referencias distintas explícitas, son 2 pagos reales distintos
          if (normCandidate.referenceId != null &&
              existing.referenceId != null &&
              normCandidate.referenceId != existing.referenceId) {
            continue;
          }

          final timeDiff =
              normCandidate.timestamp.difference(existing.timestamp).abs();
          if (timeDiff > lateDuplicateWindow) continue;

          final multiAppRule = _findMultiAppRule(
            allRules: allRules,
            candPkg: normCandidate.packageName,
            candChannel: normCandidate.channel.wireValue,
            candMerchant: normCandidate.normalizedMerchant,
            targetPackages: _extractPackages(entry.item),
            targetChannels: _extractChannels(entry.item),
            targetMerchant: existing.normalizedMerchant,
          );

          if (multiAppRule != null) {
            return CorrelationResult(
              decision: CorrelationDecisionType.probabilisticDuplicate,
              matchedPendingItemId: entry.item.id,
              similarityScore: 1.0,
              reason:
                  'Regla multi-app aprendida (${multiAppRule.merchantKey}, Δ=${timeDiff.inMinutes}m)',
            );
          }
        }

        final corpus = searchPool
            .map((e) => e.norm.normalizedMerchant.isNotEmpty
                ? e.norm.normalizedMerchant
                : e.norm.rawText)
            .toList();

        final learnedRule = normCandidate.normalizedMerchant.isNotEmpty
            ? await findDedupRule(normCandidate.normalizedMerchant)
            : null;

        for (final entry in searchPool) {
          final existing = entry.norm;

          // Misma dirección (no mezclar débito con crédito aquí)
          if (normCandidate.type != existing.type) continue;
          if (normCandidate.type == 'transferencia') continue;

          // Monto exacto
          if ((normCandidate.amount - existing.amount).abs() >= 0.01) continue;

          // Ventana temporal estricta de 48h (evita colisión con compras recurrentes mensuales)
          final timeDiff =
              normCandidate.timestamp.difference(existing.timestamp).abs();
          final effectiveRule = learnedRule ??
              (existing.normalizedMerchant.isNotEmpty
                  ? await findDedupRule(existing.normalizedMerchant)
                  : null);
          final effectiveWindow = effectiveRule != null
              ? Duration(hours: effectiveRule.mergeWindowHours)
              : correlationWindow;
          if (timeDiff > effectiveWindow) continue;

          // Si ambos traen referencias distintas explícitas, son 2 pagos reales distintos
          if (normCandidate.referenceId != null &&
              existing.referenceId != null &&
              normCandidate.referenceId != existing.referenceId) {
            continue;
          }

          final candText = normCandidate.normalizedMerchant.isNotEmpty
              ? normCandidate.normalizedMerchant
              : normCandidate.rawText;
          final existText = existing.normalizedMerchant.isNotEmpty
              ? existing.normalizedMerchant
              : existing.rawText;

          if (candText.isEmpty || existText.isEmpty) continue;

          final similarity = TextSimilarityIndex.combinedSimilarity(
            candText,
            existText,
            corpus: corpus,
          );

          final threshold = effectiveRule != null
              ? 0.80
              : probabilisticSimilarityThreshold;

          if (similarity >= threshold) {
            return CorrelationResult(
              decision: CorrelationDecisionType.probabilisticDuplicate,
              matchedPendingItemId: entry.item.id,
              similarityScore: similarity,
              reason:
                  'Duplicado probable (similitud ${similarity.toStringAsFixed(2)}, Δ=${timeDiff.inMinutes}m)',
            );
          }
        }
      }
    }

    // Fase 3: Consultar anillo de 48h de movimientos recién confirmados/corregidos
    // Solo bloquea avisos tardíos con evidencia fuerte:
    // 1) referenceId idéntico + mismo monto exacto, o
    // 2) DedupRule multi-app aprendida + mismo monto exacto + ventana <= 60 min + distinto paquete/canal.
    final recentConfirmed = await getRecentMovements(now: now);
    for (final recent in recentConfirmed) {
      if ((normCandidate.amount - recent.amount).abs() >= 0.01) continue;

      if (normCandidate.referenceId != null &&
          recent.referenceId != null &&
          normCandidate.referenceId == recent.referenceId) {
        return CorrelationResult(
          decision: CorrelationDecisionType.alreadyConfirmedDuplicate,
          matchedConfirmedMovementId: recent.id,
          similarityScore: 1.0,
          reason:
              'Operación ya confirmada recientemente (referencia ${normCandidate.referenceId})',
        );
      }

      if (normCandidate.referenceId != null &&
          recent.referenceId != null &&
          normCandidate.referenceId != recent.referenceId) {
        continue;
      }

      final timeDiff = normCandidate.timestamp.difference(recent.timestamp).abs();
      if (timeDiff > lateDuplicateWindow) continue;

      final candPkg = normCandidate.packageName;
      final recPackages = recent.allPackages;
      final candChan = normCandidate.channel.wireValue;
      final recChan = recent.channel;

      final isDifferentSource = (candPkg.isNotEmpty && recPackages.isNotEmpty)
          ? !recPackages.contains(candPkg) || candChan != recChan
          : candChan != recChan;
      if (!isDifferentSource) continue;

      final multiAppRule = _findMultiAppRule(
        allRules: allRules,
        candPkg: candPkg,
        candChannel: candChan,
        candMerchant: normCandidate.normalizedMerchant,
        targetPackages: recPackages,
        targetChannels: {recChan},
        targetMerchant: recent.merchantKey ?? '',
      );

      if (multiAppRule != null) {
        return CorrelationResult(
          decision: CorrelationDecisionType.alreadyConfirmedDuplicate,
          matchedConfirmedMovementId: recent.id,
          similarityScore: 1.0,
          reason:
              'Duplicado tardío de operación ya confirmada (${multiAppRule.merchantKey}, Δ=${timeDiff.inMinutes}m)',
        );
      }
    }

    return const CorrelationResult(
      decision: CorrelationDecisionType.unique,
      reason: 'Movimiento único tras evaluación blocking/matching',
    );
  }

  CorrelationResult? _tryInternalTransferPair({
    required NormalizedNotificationMovement candidate,
    required NormalizedNotificationMovement existing,
  }) {
    final isDebitCreditPair =
        (candidate.type == 'debito' && existing.type == 'credito') ||
            (candidate.type == 'credito' && existing.type == 'debito');
    if (!isDebitCreditPair) return null;

    if ((candidate.amount - existing.amount).abs() >= 0.01) return null;

    final timeDiff = candidate.timestamp.difference(existing.timestamp).abs();
    if (timeDiff > correlationWindow) return null;

    final accA = candidate.inferredAccount;
    final accB = existing.inferredAccount;
    if (accA == null ||
        accA.trim().isEmpty ||
        accB == null ||
        accB.trim().isEmpty) {
      return null;
    }
    if (accA.trim().toLowerCase() == accB.trim().toLowerCase()) return null;

    final sourceAcc = candidate.type == 'debito' ? accA : accB;
    final destAcc = candidate.type == 'debito' ? accB : accA;

    return CorrelationResult(
      decision: CorrelationDecisionType.internalTransferPair,
      matchedPendingItemId: existing.id,
      similarityScore: 1.0,
      reason: 'Correlación transferencia interna ($sourceAcc -> $destAcc)',
      proposedSourceAccount: sourceAcc,
      proposedDestinationAccount: destAcc,
    );
  }

  List<String> _collectChannelLabels(List<Map<String, dynamic>> events) {
    final seen = <String>{};
    for (final ev in events) {
      final ch = (ev['channel'] as String?)?.trim();
      if (ch != null && ch.isNotEmpty) {
        seen.add(ch);
      }
    }
    return seen.isEmpty ? const ['app'] : seen.toList();
  }

  /// Fusiona un movimiento entrante con un ítem pendiente existente para proponer
  /// exactamente 1 movimiento (preservando los eventos originales en `groupedEvents`
  /// por si el usuario decide separarlos).
  PendingTransactionItem mergeIntoPendingItem({
    required PendingTransactionItem existing,
    required PendingTransactionItem incoming,
    required CorrelationResult correlation,
  }) {
    final existingEvents = existing.groupedEvents.isNotEmpty
        ? List<Map<String, dynamic>>.from(existing.groupedEvents)
        : <Map<String, dynamic>>[
            existing.copyWith(groupedEvents: const []).toJson(),
          ];

    final incomingPayload = incoming.groupedEvents.isNotEmpty
        ? incoming.groupedEvents
        : <Map<String, dynamic>>[
            incoming.copyWith(groupedEvents: const []).toJson(),
          ];
    existingEvents.addAll(incomingPayload);

    final channelLabels = _collectChannelLabels(existingEvents);
    final mergedFlags = <String>{
      ...existing.flags,
      ...incoming.flags,
      if (correlation.decision == CorrelationDecisionType.internalTransferPair)
        'correlated_internal_transfer'
      else
        'dedup_grouped',
    }.toList();

    if (correlation.decision == CorrelationDecisionType.internalTransferPair) {
      final sourceAcc =
          correlation.proposedSourceAccount ?? existing.accountName;
      final destAcc =
          correlation.proposedDestinationAccount ?? existing.destinationAccount;
      final canAuto = sourceAcc != null &&
          sourceAcc.isNotEmpty &&
          destAcc != null &&
          destAcc.isNotEmpty;

      return existing.copyWith(
        classification: 'transferencia-propia',
        moneoType: 'Transfer',
        category: 'Transferencia',
        accountName: sourceAcc,
        destinationAccount: destAcc,
        comercio:
            existing.comercio ?? incoming.comercio ?? 'Transferencia propia',
        confidence: canAuto ? 0.93 : existing.confidence,
        requiresReview: !canAuto,
        autoProcessable: canAuto,
        decisionSource: 'transfer_correlation',
        flags: mergedFlags,
        groupedEvents: existingEvents,
        strategicNote:
            'Correlacionado automáticamente ($sourceAcc → $destAcc) en 1 transferencia (${existingEvents.length} avisos: ${channelLabels.join(', ')})',
      );
    }

    final bestAccount = existing.accountName ?? incoming.accountName;
    final bestDestination =
        existing.destinationAccount ?? incoming.destinationAccount;
    final bestConfidence = existing.confidence >= incoming.confidence
        ? existing.confidence
        : incoming.confidence;

    final upgradeToTransfer = existing.classification != 'transferencia-propia' &&
        incoming.classification == 'transferencia-propia' &&
        bestAccount != null &&
        bestAccount.isNotEmpty &&
        bestDestination != null &&
        bestDestination.isNotEmpty;

    return existing.copyWith(
      classification:
          upgradeToTransfer ? 'transferencia-propia' : existing.classification,
      moneoType: upgradeToTransfer ? 'Transfer' : existing.moneoType,
      category: upgradeToTransfer ? 'Transferencia' : existing.category,
      accountName: bestAccount,
      destinationAccount: bestDestination,
      referenceId: existing.referenceId ?? incoming.referenceId,
      confidence: bestConfidence,
      flags: mergedFlags,
      groupedEvents: existingEvents,
      strategicNote:
          'Agrupado (${existingEvents.length} avisos: ${channelLabels.join(', ')}) para evitar duplicado',
    );
  }

  /// Guarda una regla reutilizable cuando el usuario confirma "estos N son uno"
  /// o confirma/corrige 1 notificación y descarta sus duplicados paralelos.
  Future<DedupRule?> learnMergeRule({
    required String merchant,
    List<String> channels = const [],
    List<String> packages = const [],
    DateTime? at,
  }) async {
    final key = LearnedPatternsService.normalizeMerchant(merchant);
    if (key.isEmpty) return null;

    final cleanChannels =
        channels.map((c) => c.trim()).where((c) => c.isNotEmpty).toSet().toList();
    final cleanPackages =
        packages.map((p) => p.trim()).where((p) => p.isNotEmpty).toSet().toList();

    final now = at ?? DateTime.now();
    final existing = await findDedupRule(key);
    final updated = existing != null
        ? existing.increment(
            extraChannels: cleanChannels,
            extraPackages: cleanPackages,
            at: now,
          )
        : DedupRule(
            merchantKey: key,
            channels: cleanChannels,
            packages: cleanPackages,
            mergeWindowHours: 48,
            confirmations: 1,
            createdAt: now,
            lastUsedAt: now,
          );

    _memoryRules[key] = updated;
    final box = await _getRulesBox();
    if (box != null) {
      await box.put(key, updated.toJson());
    }
    return updated;
  }

  Future<DedupRule?> findDedupRule(String merchant) async {
    final key = LearnedPatternsService.normalizeMerchant(merchant);
    if (key.isEmpty) return null;
    if (_memoryRules.containsKey(key)) return _memoryRules[key];

    final box = await _getRulesBox();
    final raw = box?.get(key);
    if (raw is Map) {
      final rule = DedupRule.fromJson(Map<String, dynamic>.from(raw));
      _memoryRules[key] = rule;
      return rule;
    }
    return null;
  }

  /// Limpia reglas y el anillo de movimientos recientes en memoria y persistencia.
  Future<void> clearAll() async {
    _memoryRules.clear();
    _memoryRecentMovements.clear();
    _recentLoadedFromBox = false;
    final rulesBox = await _getRulesBox();
    if (rulesBox != null) {
      await rulesBox.clear();
    }
    final recentBox = await _getRecentMovementsBox();
    if (recentBox != null) {
      await recentBox.clear();
    }
  }
}
