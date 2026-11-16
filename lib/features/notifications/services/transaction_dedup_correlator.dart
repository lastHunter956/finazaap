import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/domain/models/dedup_models.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/text_similarity_index.dart';

/// Motor de deduplicación y correlación de notificaciones ANTES de crear movimientos.
///
/// Pipeline estricto:
/// `normalizar -> blocking -> matching -> agrupar -> proponer 1 movimiento -> usuario confirma/separa`.
class TransactionDedupCorrelator {
  static const String defaultRulesBoxName = 'notification_dedup_rules';
  static const double probabilisticSimilarityThreshold = 0.90;
  static const Duration correlationWindow = Duration(hours: 48);

  static final RegExp _referenceRegex = RegExp(
    r'\b(?:utr|ref(?:erencia)?|comprobante|aprob(?:acion|ación)?|autorizacion|autorizaci[oó]n|cus)\b[:\s#-]*([a-z0-9]{4,24})\b',
    caseSensitive: false,
  );

  final Box<dynamic>? _injectedRulesBox;
  final NotificationBoxEncryption? _boxEncryption;
  final Map<String, DedupRule> _memoryRules = {};

  TransactionDedupCorrelator({
    Box<dynamic>? rulesBox,
    NotificationBoxEncryption? boxEncryption,
  })  : _injectedRulesBox = rulesBox,
        _boxEncryption = boxEncryption;

  Future<Box<dynamic>?> _getRulesBox() async {
    if (_injectedRulesBox != null) return _injectedRulesBox;
    if (_boxEncryption != null) {
      return _boxEncryption!.openEncryptedBox(defaultRulesBoxName);
    }
    if (Hive.isBoxOpen(defaultRulesBoxName)) {
      return Hive.box<dynamic>(defaultRulesBoxName);
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
        pkg.contains('mms') ||
        text.startsWith('sms:')) {
      return NotificationChannel.sms;
    }
    if (pkg.contains('gmail') ||
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
    final merchantSource = item.comercio ?? item.merchantKey ?? '';
    final normalizedMerchant =
        LearnedPatternsService.normalizeMerchant(merchantSource);
    final amount = item.monto ?? 0.0;
    final refId = item.referenceId ?? extractReferenceId(item.rawText);
    final channel = inferChannel(
      packageName: packageName,
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
      packageName: packageName ?? '',
    );
  }

  /// Evalúa un candidato entrante contra la lista de ítems pendientes existentes
  /// ANTES de crear un nuevo movimiento en bandeja.
  Future<CorrelationResult> correlate({
    required PendingTransactionItem candidate,
    required List<PendingTransactionItem> existingPending,
    String? packageName,
  }) async {
    if (existingPending.isEmpty || candidate.monto == null || candidate.monto! <= 0) {
      return const CorrelationResult(
        decision: CorrelationDecisionType.unique,
        reason: 'Sin candidatos previos compatibles',
      );
    }

    final normCandidate = normalizeItem(candidate, packageName: packageName);

    // Fase 1: Blocking por monto redondeado y ventana temporal (48h)
    final normalizedExisting = existingPending
        .where((e) =>
            e.id != candidate.id &&
            e.monto != null &&
            e.classification != 'sospechosa')
        .map((e) => (item: e, norm: normalizeItem(e)))
        .toList();

    final blockingByKey = <String, List<({PendingTransactionItem item, NormalizedNotificationMovement norm})>>{};
    final blockingByAmount = <int, List<({PendingTransactionItem item, NormalizedNotificationMovement norm})>>{};

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
              reason: 'Coincidencia determinista por referencia ${normCandidate.referenceId}',
            );
          }
        }
      }
    }

    final amountBucket = blockingByAmount[normCandidate.roundedAmount] ?? const [];
    if (amountBucket.isEmpty) {
      return const CorrelationResult(
        decision: CorrelationDecisionType.unique,
        reason: 'Sin coincidencias en bucket de monto',
      );
    }

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

    // Fase 2C: Matching probabilístico (monto exacto + ventana 48h + similitud >= 0.90)
    final sameKeyBucket = blockingByKey[normCandidate.blockingKey] ?? const [];
    final searchPool = <({PendingTransactionItem item, NormalizedNotificationMovement norm})>{
      ...sameKeyBucket,
      ...amountBucket,
    }.toList();

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
      final timeDiff = normCandidate.timestamp.difference(existing.timestamp).abs();
      final effectiveWindow = learnedRule != null
          ? Duration(hours: learnedRule.mergeWindowHours)
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

      final threshold = learnedRule != null
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
        comercio: existing.comercio ?? incoming.comercio ?? 'Transferencia propia',
        confidence: canAuto ? 0.93 : existing.confidence,
        requiresReview: !canAuto,
        autoProcessable: canAuto,
        decisionSource: 'transfer_correlation',
        flags: mergedFlags,
        groupedEvents: existingEvents,
        strategicNote:
            'Correlacionado automáticamente ($sourceAcc → $destAcc) en 1 transferencia',
      );
    }

    final bestAccount = existing.accountName ?? incoming.accountName;
    final bestConfidence = existing.confidence >= incoming.confidence
        ? existing.confidence
        : incoming.confidence;

    return existing.copyWith(
      accountName: bestAccount,
      referenceId: existing.referenceId ?? incoming.referenceId,
      confidence: bestConfidence,
      flags: mergedFlags,
      groupedEvents: existingEvents,
      strategicNote:
          'Agrupado (${existingEvents.length} notificaciones) para evitar duplicado',
    );
  }

  /// Guarda una regla reutilizable cuando el usuario confirma "estos N son uno".
  Future<DedupRule?> learnMergeRule({
    required String merchant,
    List<String> channels = const [],
    DateTime? at,
  }) async {
    final key = LearnedPatternsService.normalizeMerchant(merchant);
    if (key.isEmpty) return null;

    final now = at ?? DateTime.now();
    final existing = await findDedupRule(key);
    final updated = existing != null
        ? existing.increment(extraChannels: channels, at: now)
        : DedupRule(
            merchantKey: key,
            channels: channels.toSet().toList(),
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
}
