import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/features/notifications/adapters/android_notification_source.dart';
import 'package:finazaap/features/notifications/adapters/real_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/domain/models/spam_models.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/notification_ingestion_service.dart';
import 'package:finazaap/features/notifications/services/notification_parser.dart';
import 'package:finazaap/features/notifications/services/spam_patterns_service.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';
import 'package:finazaap/features/notifications/services/transaction_dedup_correlator.dart';

/// Registro efímero en RAM (solo apps permitidas) para diagnóstico local en Ajustes.
class NotificationDiagnosticEntry {
  final DateTime timestamp;
  final String packageName;
  final String appName;
  final String? channelId;
  final String outcome; // 'pending' | 'spam' | 'auto_accepted' | 'dedup' | 'unparseable' | 'merged' | 'already_confirmed'
  final String detail;
  final String titlePreview;

  const NotificationDiagnosticEntry({
    required this.timestamp,
    required this.packageName,
    required this.appName,
    this.channelId,
    required this.outcome,
    required this.detail,
    required this.titlePreview,
  });
}

class _RecentCrossContextRecord {
  final DateTime timestamp;
  final String summary;

  const _RecentCrossContextRecord({
    required this.timestamp,
    required this.summary,
  });
}

/// Coordinador del pipeline real de notificaciones bancarias en Moneo.
///
/// Conecta:
/// Fuente (Android / puerto inyectado) -> Whitelist + Dedup -> Pre-filtros + Parser ->
/// Ventana cruzada adaptativa (5 min en background / flush inmediato al abrir app) ->
/// Clasificador jerárquico (Anti-Fraude -> Spam 0-IA -> Mini-RAG -> IA Context-Aware -> Fallback) ->
/// Correlador Multi-App -> Bandeja cifrada (`Pendientes` | `Spam 5 días`) ->
/// Contabilidad real (`RealTransactionExecutionAdapter`).
class NotificationPipelineService {
  static const String captureEnabledPrefsKey = 'notifications_capture_enabled';
  static const String autoAcceptFuturePrefsKey =
      'notifications_auto_accept_future';
  static const String dedupHistoryBoxName = 'notification_dedup_history';
  static const Duration dedupHistoryTtl = Duration(days: 30);
  static const Duration defaultBatchWindow = Duration(minutes: 5);
  static const Duration crossContextHorizon = Duration(minutes: 10);
  static const int maxBatchSize = 6;
  static const int maxDiagnosticEntries = 25;

  static final NotificationPipelineService instance =
      NotificationPipelineService._internal();

  factory NotificationPipelineService({
    NotificationBoxEncryption? boxEncryption,
    BankWhitelistService? whitelistService,
    NotificationSourcePort? source,
    TransactionExecutionPort? executionPort,
    Box<dynamic>? dedupBox,
    Box<dynamic>? pendingBox,
    Box<dynamic>? executedBox,
    Box<dynamic>? patternsBox,
    Box<dynamic>? dedupRulesBox,
    Box<dynamic>? recentMovementsBox,
    Box<dynamic>? spamBox,
    Box<dynamic>? dismissedPatternsBox,
    TransactionDedupCorrelator? dedupCorrelator,
    TransactionClassifier? classifier,
    SpamPatternsService? spamPatternsService,
    Duration? batchWindow,
    bool? enableAiEnrichment,
  }) {
    if (boxEncryption == null &&
        whitelistService == null &&
        source == null &&
        executionPort == null &&
        dedupBox == null &&
        pendingBox == null &&
        executedBox == null &&
        patternsBox == null &&
        dedupRulesBox == null &&
        recentMovementsBox == null &&
        spamBox == null &&
        dismissedPatternsBox == null &&
        dedupCorrelator == null &&
        classifier == null &&
        spamPatternsService == null &&
        batchWindow == null &&
        enableAiEnrichment == null) {
      return instance;
    }
    return NotificationPipelineService._custom(
      boxEncryption: boxEncryption,
      whitelistService: whitelistService,
      source: source,
      executionPort: executionPort,
      dedupBox: dedupBox,
      pendingBox: pendingBox,
      executedBox: executedBox,
      patternsBox: patternsBox,
      dedupRulesBox: dedupRulesBox,
      recentMovementsBox: recentMovementsBox,
      spamBox: spamBox,
      dismissedPatternsBox: dismissedPatternsBox,
      dedupCorrelator: dedupCorrelator,
      classifier: classifier,
      spamPatternsService: spamPatternsService,
      batchWindow: batchWindow ?? Duration.zero,
      enableAiEnrichment: enableAiEnrichment ?? false,
    );
  }

  NotificationPipelineService._internal()
      : _boxEncryption = NotificationBoxEncryption(),
        _whitelistService = BankWhitelistService(),
        _source = AndroidNotificationSource(),
        _executionPort = RealTransactionExecutionAdapter(),
        _injectedDedupBox = null,
        _injectedPendingBox = null,
        _injectedExecutedBox = null,
        _injectedPatternsBox = null,
        _injectedDedupRulesBox = null,
        _injectedRecentMovementsBox = null,
        _injectedSpamBox = null,
        _injectedDismissedPatternsBox = null,
        _injectedDedupCorrelator = null,
        _injectedClassifier = null,
        _injectedSpamPatternsService = null,
        _batchWindow = defaultBatchWindow,
        _enableAiEnrichment = true {
    _buildCollaborators();
  }

  NotificationPipelineService._custom({
    NotificationBoxEncryption? boxEncryption,
    BankWhitelistService? whitelistService,
    NotificationSourcePort? source,
    TransactionExecutionPort? executionPort,
    Box<dynamic>? dedupBox,
    Box<dynamic>? pendingBox,
    Box<dynamic>? executedBox,
    Box<dynamic>? patternsBox,
    Box<dynamic>? dedupRulesBox,
    Box<dynamic>? recentMovementsBox,
    Box<dynamic>? spamBox,
    Box<dynamic>? dismissedPatternsBox,
    TransactionDedupCorrelator? dedupCorrelator,
    TransactionClassifier? classifier,
    SpamPatternsService? spamPatternsService,
    required Duration batchWindow,
    required bool enableAiEnrichment,
  })  : _boxEncryption = boxEncryption ?? NotificationBoxEncryption(),
        _whitelistService = whitelistService ?? BankWhitelistService(),
        _source = source ?? AndroidNotificationSource(),
        _executionPort = executionPort ?? RealTransactionExecutionAdapter(),
        _injectedDedupBox = dedupBox,
        _injectedPendingBox = pendingBox,
        _injectedExecutedBox = executedBox,
        _injectedPatternsBox = patternsBox,
        _injectedDedupRulesBox = dedupRulesBox,
        _injectedRecentMovementsBox = recentMovementsBox,
        _injectedSpamBox = spamBox,
        _injectedDismissedPatternsBox = dismissedPatternsBox,
        _injectedDedupCorrelator = dedupCorrelator,
        _injectedClassifier = classifier,
        _injectedSpamPatternsService = spamPatternsService,
        _batchWindow = batchWindow,
        _enableAiEnrichment = enableAiEnrichment {
    _buildCollaborators();
  }

  final NotificationBoxEncryption _boxEncryption;
  final BankWhitelistService _whitelistService;
  final NotificationSourcePort _source;
  final TransactionExecutionPort _executionPort;
  final Box<dynamic>? _injectedDedupBox;
  final Box<dynamic>? _injectedPendingBox;
  final Box<dynamic>? _injectedExecutedBox;
  final Box<dynamic>? _injectedPatternsBox;
  final Box<dynamic>? _injectedDedupRulesBox;
  final Box<dynamic>? _injectedRecentMovementsBox;
  final Box<dynamic>? _injectedSpamBox;
  final Box<dynamic>? _injectedDismissedPatternsBox;
  final TransactionDedupCorrelator? _injectedDedupCorrelator;
  final TransactionClassifier? _injectedClassifier;
  final SpamPatternsService? _injectedSpamPatternsService;
  final Duration _batchWindow;
  final bool _enableAiEnrichment;

  late final NotificationIngestionService _ingestionService;
  late final NotificationParser _parser;
  late final LearnedPatternsService _patternsService;
  late final SpamPatternsService? _spamPatternsService;
  late final TransactionClassifier _classifier;
  late final TransactionDedupCorrelator _dedupCorrelator;
  late final PendingTransactionsNotifier _pendingNotifier;

  StreamSubscription<NotificationEvent>? _ingestedSubscription;
  Future<void> _processingChain = Future<void>.value();
  final List<NotificationEvent> _batchBuffer = [];
  Timer? _batchTimer;
  final List<_RecentCrossContextRecord> _recentCrossContext = [];
  final List<NotificationDiagnosticEntry> _diagnosticLog = [];

  List<AccountItem>? _cachedAccounts;
  DateTime? _cachedAccountsAt;
  static const Duration _accountsCacheTtl = Duration(seconds: 5);
  bool _initialized = false;
  bool _captureEnabled = false;
  bool _autoAcceptFutureEnabled = false;

  void _buildCollaborators() {
    _ingestionService = NotificationIngestionService(
      whitelistService: _whitelistService,
    );
    _parser = NotificationParser();
    _patternsService = LearnedPatternsService(
      box: _injectedPatternsBox,
      boxEncryption: _injectedPatternsBox == null ? _boxEncryption : null,
    );

    final hasCustomStorage = _injectedPendingBox != null ||
        _injectedDedupBox != null ||
        _injectedPatternsBox != null;
    _spamPatternsService = _injectedSpamPatternsService ??
        (_injectedDismissedPatternsBox != null
            ? SpamPatternsService(box: _injectedDismissedPatternsBox)
            : (!hasCustomStorage
                ? SpamPatternsService(boxEncryption: _boxEncryption)
                : null));

    _classifier = _injectedClassifier ??
        TransactionClassifier(
          patternsService: _patternsService,
          spamPatternsService: _spamPatternsService,
          enableAiEnrichment: _enableAiEnrichment,
        );
    _dedupCorrelator = _injectedDedupCorrelator ??
        TransactionDedupCorrelator(
          rulesBox: _injectedDedupRulesBox,
          recentMovementsBox: _injectedRecentMovementsBox,
          boxEncryption: (_injectedDedupRulesBox == null ||
                  _injectedRecentMovementsBox == null)
              ? _boxEncryption
              : null,
        );
    _pendingNotifier = PendingTransactionsNotifier(
      box: _injectedPendingBox,
      executedBox: _injectedExecutedBox,
      spamBox: _injectedSpamBox,
      boxEncryption: _injectedPendingBox == null ? _boxEncryption : null,
      learnedPatternsService: _patternsService,
      spamPatternsService: _spamPatternsService,
      executionPort: _executionPort,
      dedupCorrelator: _dedupCorrelator,
    );
  }

  BankWhitelistService get whitelistService => _whitelistService;
  NotificationSourcePort get source => _source;
  LearnedPatternsService get patternsService => _patternsService;
  SpamPatternsService? get spamPatternsService => _spamPatternsService;
  TransactionDedupCorrelator get dedupCorrelator => _dedupCorrelator;
  PendingTransactionsNotifier get pendingNotifier => _pendingNotifier;
  bool get isCaptureEnabled => _captureEnabled;
  bool get isAutoAcceptFutureEnabled => _autoAcceptFutureEnabled;
  int get bufferedBatchCount => _batchBuffer.length;

  /// Últimos 25 eventos recibidos de apps permitidas y su resultado en el pipeline.
  List<NotificationDiagnosticEntry> get diagnosticLog =>
      List.unmodifiable(_diagnosticLog);

  void clearDiagnosticLog() {
    _diagnosticLog.clear();
  }

  void _recordDiagnostic({
    required NotificationEvent event,
    required String outcome,
    required String detail,
  }) {
    final appName =
        _whitelistService.getBankName(event.packageName) ?? event.packageName;
    final preview = event.title.trim().isNotEmpty
        ? event.title.trim()
        : (event.body.trim().length > 48
            ? '${event.body.trim().substring(0, 48)}...'
            : event.body.trim());
    _diagnosticLog.insert(
      0,
      NotificationDiagnosticEntry(
        timestamp: DateTime.now(),
        packageName: event.packageName,
        appName: appName,
        channelId: event.channelId,
        outcome: outcome,
        detail: detail,
        titlePreview: preview,
      ),
    );
    if (_diagnosticLog.length > maxDiagnosticEntries) {
      _diagnosticLog.removeRange(maxDiagnosticEntries, _diagnosticLog.length);
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    await _whitelistService.loadFromPrefs();
    final prefs = await SharedPreferences.getInstance();
    _captureEnabled = prefs.getBool(captureEnabledPrefsKey) ?? false;
    _autoAcceptFutureEnabled = prefs.getBool(autoAcceptFuturePrefsKey) ?? false;

    try {
      await _pendingNotifier.initialize();
      if (_injectedDedupBox != null ||
          _injectedExecutedBox != null ||
          _injectedPendingBox != null) {
        await pruneStorageTtl();
        await _dedupCorrelator.warmUp();
        await _getRecentAccounts();
      } else {
        unawaited(pruneStorageTtl().catchError((_) => (
              dedupPruned: 0,
              executedPruned: 0,
              patternsPruned: 0,
              spamPruned: 0,
            )));
        unawaited(_dedupCorrelator.warmUp().catchError((_) {}));
      }
    } catch (_) {
      // Permite continuar en entornos de prueba sin plugin de FlutterSecureStorage.
    }

    _ingestedSubscription ??=
        _ingestionService.ingestedStream.listen(_enqueueEvent);
    _ingestionService.attachSource(_source);

    await _syncNativeConfig();

    if (_captureEnabled) {
      await _source.startListening();
    }

    _initialized = true;
  }

  Future<void> setCaptureEnabled(bool enabled) async {
    _captureEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(captureEnabledPrefsKey, enabled);

    await _syncNativeConfig();

    if (enabled) {
      await _source.startListening();
    } else {
      await _source.stopListening();
    }
  }

  Future<void> setAutoAcceptFutureEnabled(bool enabled) async {
    _autoAcceptFutureEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoAcceptFuturePrefsKey, enabled);
  }

  Future<void> syncWhitelistToNative() async {
    await _syncNativeConfig();
  }

  Future<void> _syncNativeConfig() async {
    final src = _source;
    if (src is AndroidNotificationSource) {
      await src.syncConfig(
        enabled: _captureEnabled,
        allowedPackages: _whitelistService.whitelistedPackages.toList(),
      );
    }
  }

  /// Ejecuta la poda TTL y compactación (`box.compact()`) sobre las cajas
  /// `notification_dedup_history` (>30 días), `notification_executed_ids`
  /// (>90 días o tope 500), `learned_patterns` obsoletos (>180 días) y
  /// `notification_spam_items` (>5 días).
  Future<({int dedupPruned, int executedPruned, int patternsPruned, int spamPruned})>
      pruneStorageTtl({DateTime? now}) async {
    final reference = now ?? DateTime.now();
    var dedupPruned = 0;
    var executedPruned = 0;
    var patternsPruned = 0;
    var spamPruned = 0;

    try {
      final dedupBox = await _getDedupBox();
      final keysToDelete = <dynamic>[];
      for (final key in dedupBox.keys) {
        final raw = dedupBox.get(key);
        final ts = raw is String ? DateTime.tryParse(raw) : null;
        if (ts == null || reference.difference(ts) > dedupHistoryTtl) {
          keysToDelete.add(key);
        }
      }
      for (final key in keysToDelete) {
        await dedupBox.delete(key);
      }
      if (keysToDelete.isNotEmpty) {
        await dedupBox.compact();
      }
      dedupPruned = keysToDelete.length;
    } catch (_) {}

    try {
      executedPruned = await _pendingNotifier.pruneExecutedHistory(now: reference);
    } catch (_) {}

    try {
      patternsPruned =
          await _patternsService.pruneObsoletePatterns(now: reference);
    } catch (_) {}

    try {
      spamPruned = await _pendingNotifier.pruneExpiredSpam(now: reference);
    } catch (_) {}

    try {
      await _dedupCorrelator.pruneRecentMovements(now: reference);
    } catch (_) {}

    return (
      dedupPruned: dedupPruned,
      executedPruned: executedPruned,
      patternsPruned: patternsPruned,
      spamPruned: spamPruned,
    );
  }

  /// Drena eventos acumulados cuando la app regresa a primer plano y hace flush
  /// inmediato de la ventana de 5 min para UX instantánea.
  Future<void> syncOnResume() async {
    _cachedAccounts = null;
    _cachedAccountsAt = null;
    if (!_initialized) {
      await initialize();
    }
    await _syncNativeConfig();
    if (!_captureEnabled) return;

    final status = await _source.checkStatus();
    if (status.permissionStatus != NotificationPermissionStatus.granted) {
      await _source.stopListening();
      return;
    }

    final src = _source;
    if (src is AndroidNotificationSource) {
      if (!src.isListening) {
        await src.startListening();
      } else {
        await src.drainPendingEvents(includeActive: true);
      }
    }

    if (_batchBuffer.isNotEmpty) {
      await flushBatchNow();
    }
  }

  Future<Box<dynamic>> _getDedupBox() async {
    if (_injectedDedupBox != null) return _injectedDedupBox!;
    return _boxEncryption.openEncryptedBox(dedupHistoryBoxName);
  }

  /// Fuerza el procesamiento inmediato del lote acumulado en la ventana de 5 min
  /// (usado al abrir la app/bandeja o al finalizar pruebas).
  Future<void> flushBatchNow() async {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_batchBuffer.isNotEmpty) {
      final batch = List<NotificationEvent>.from(_batchBuffer);
      _batchBuffer.clear();
      _processingChain = _processingChain
          .then((_) => _processBatch(batch))
          .catchError((_) {});
    }
    await _processingChain;
  }

  /// Espera a que termine cualquier evento actualmente en la cola o en la ventana de lote.
  Future<void> flushPendingProcessing() => flushBatchNow();

  void _enqueueEvent(NotificationEvent event) {
    if (_batchWindow == Duration.zero) {
      _processingChain = _processingChain
          .then((_) => _processBatch([event]))
          .catchError((_) {});
      return;
    }

    _batchBuffer.add(event);
    if (_batchBuffer.length >= maxBatchSize) {
      unawaited(flushBatchNow());
      return;
    }

    _batchTimer ??= Timer(_batchWindow, () {
      unawaited(flushBatchNow());
    });
  }

  Future<List<AccountItem>> _getRecentAccounts() async {
    final now = DateTime.now();
    if (_cachedAccounts != null &&
        _cachedAccountsAt != null &&
        now.difference(_cachedAccountsAt!) < _accountsCacheTtl) {
      return _cachedAccounts!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('accounts') ?? const <String>[];
      final parsed = rawList
          .map((raw) {
            try {
              final map = jsonDecode(raw) as Map<String, dynamic>;
              return AccountItem.fromJson(map);
            } catch (_) {
              return null;
            }
          })
          .whereType<AccountItem>()
          .toList();
      _cachedAccounts = parsed;
      _cachedAccountsAt = now;
      return parsed;
    } catch (_) {
      return _cachedAccounts ?? const <AccountItem>[];
    }
  }

  void _pruneCrossContext(DateTime now) {
    _recentCrossContext.removeWhere(
      (r) => now.difference(r.timestamp).abs() > crossContextHorizon,
    );
  }

  String _summarizeEventForCrossContext(
    NotificationEvent event,
    NotificationParseResult parseResult,
  ) {
    final appName =
        _whitelistService.getBankName(event.packageName) ?? event.packageName;
    final amountStr = (parseResult is ParsedTransaction &&
            parseResult.monto != null)
        ? ' ${parseResult.moneda} ${parseResult.monto!.toStringAsFixed(0)}'
        : '';
    final tipo = parseResult is ParsedTransaction ? parseResult.tipo : 'aviso';
    final rawPreview = [event.title.trim(), event.enrichedBody.trim()]
        .where((s) => s.isNotEmpty)
        .join(' - ');
    final shortPreview = rawPreview.length > 70
        ? '${rawPreview.substring(0, 70)}...'
        : rawPreview;
    return '[$appName|$tipo$amountStr] $shortPreview';
  }

  /// Procesa un lote de eventos capturados en la ventana cruzada (hasta 5 min)
  /// compartiendo contexto entre ellos y liberando Gemma local al terminar.
  Future<void> _processBatch(List<NotificationEvent> batch) async {
    if (batch.isEmpty) return;
    final now = DateTime.now();
    _pruneCrossContext(now);

    final prepared = <({
      NotificationEvent event,
      String dedupHash,
      NotificationParseResult parseResult,
      String rawText,
      String summary,
    })>[];

    final dedupBox = await _getDedupBox();

    for (final event in batch) {
      final dedupHash = _ingestionService.computeDedupHash(event);
      if (dedupBox.containsKey(dedupHash)) {
        _recordDiagnostic(
          event: event,
          outcome: 'dedup',
          detail: 'Duplicado exacto en historial (5 min)',
        );
        continue;
      }
      await dedupBox.put(dedupHash, event.timestamp.toIso8601String());

      final parseResult = _parser.parse(event);
      if (parseResult is UnparseableNotification) {
        _recordDiagnostic(
          event: event,
          outcome: 'unparseable',
          detail: parseResult.reason,
        );
        continue;
      }

      final bodyText =
          event.enrichedBody.isNotEmpty ? event.enrichedBody : event.body.trim();
      final rawText = [event.title.trim(), bodyText]
          .where((s) => s.isNotEmpty)
          .join('. ');

      prepared.add((
        event: event,
        dedupHash: dedupHash,
        parseResult: parseResult,
        rawText: rawText,
        summary: _summarizeEventForCrossContext(event, parseResult),
      ));
    }

    if (prepared.isEmpty) return;

    final accounts = await _getRecentAccounts();
    bool usedAiInBatch = false;

    for (var i = 0; i < prepared.length; i++) {
      final current = prepared[i];
      final crossSummaries = <String>[
        for (var j = 0; j < prepared.length; j++)
          if (j != i) prepared[j].summary,
        ..._recentCrossContext.map((r) => r.summary),
      ].take(3).toList();

      final appName =
          _whitelistService.getBankName(current.event.packageName) ??
              current.event.packageName;

      final classification = await _classifier.classify(
        parseResult: current.parseResult,
        rawText: current.rawText,
        userAccounts: accounts,
        packageName: current.event.packageName,
        appName: appName,
        channelId: current.event.channelId,
        crossNotificationSummaries: crossSummaries,
      );
      if (classification.aiAnalyzed) {
        usedAiInBatch = true;
      }

      final double? parsedAmount = current.parseResult is ParsedTransaction
          ? (current.parseResult as ParsedTransaction).monto
          : null;
      final double? effectiveAmount =
          classification.suggestedAmount ?? parsedAmount;
      final String currency = current.parseResult is ParsedTransaction
          ? (current.parseResult as ParsedTransaction).moneda
          : 'COP';
      final String? parsedMerchant = current.parseResult is ParsedTransaction
          ? (current.parseResult as ParsedTransaction).comercio
          : null;
      final String? effectiveMerchant =
          (classification.suggestedDescription != null &&
                  classification.suggestedDescription!.trim().isNotEmpty)
              ? classification.suggestedDescription!.trim()
              : parsedMerchant;

      final item = PendingTransactionItem(
        id: 'notif_${current.dedupHash}',
        notificationId: current.event.id,
        rawText: current.rawText,
        merchantKey: (effectiveMerchant != null &&
                !TransactionClassifier.isGenericBankMerchant(effectiveMerchant))
            ? LearnedPatternsService.normalizeMerchant(effectiveMerchant)
            : null,
        comercio: effectiveMerchant ?? appName,
        monto: effectiveAmount,
        moneda: currency,
        fecha: current.parseResult.fecha,
        classification: classification.classification,
        moneoType: classification.moneoType,
        category: classification.category,
        accountName: classification.accountName,
        destinationAccount: classification.destinationAccount,
        confidence: current.parseResult.confidence < classification.confidence
            ? current.parseResult.confidence
            : classification.confidence,
        requiresReview:
            current.parseResult.requiresReview || classification.requiresReview,
        autoProcessable: !(current.parseResult.requiresReview ||
                classification.requiresReview) &&
            classification.classification != 'sospechosa' &&
            !classification.isSpam,
        decisionSource: classification.decisionSource,
        flags: current.parseResult.flags,
        createdAt: DateTime.now(),
        referenceId: TransactionDedupCorrelator.extractReferenceId(
          current.rawText,
        ),
        channel: TransactionDedupCorrelator.inferChannel(
          packageName: current.event.packageName,
          rawText: current.rawText,
        ).wireValue,
        packageName: current.event.packageName,
        channelId: current.event.channelId,
        strategicNote: classification.strategicNote,
      );

      // Si fue clasificada como Spam (patrón aprendido 0-IA, filtro de promo o IA)
      // -> enviar a la pestaña Spam (máx. 5 días), nunca a Pendientes.
      if (classification.isSpam) {
        final spamItem = SpamNotificationItem(
          id: item.id,
          item: item,
          spamReason: classification.spamReason ??
              'Notificación filtrada como promoción o spam',
          spamSource: classification.decisionSource,
          matchedRuleKey: classification.matchedSpamRuleKey,
          channelId: current.event.channelId,
          detectedAt: DateTime.now(),
        );
        await _pendingNotifier.addSpamItem(spamItem);
        _recordDiagnostic(
          event: current.event,
          outcome: 'spam',
          detail: spamItem.spamReason,
        );
        continue;
      }

      // Registrar en contexto cruzado deslizante (para futuras parejas en < 10 min)
      _recentCrossContext.insert(
        0,
        _RecentCrossContextRecord(
          timestamp: current.event.timestamp,
          summary: current.summary,
        ),
      );
      if (_recentCrossContext.length > 12) {
        _recentCrossContext.removeRange(12, _recentCrossContext.length);
      }

      // Deduplicación y correlación ANTES de crear un nuevo movimiento en bandeja.
      if (item.classification != 'sospechosa') {
        final correlation = await _dedupCorrelator.correlate(
          candidate: item,
          existingPending: _pendingNotifier.items,
          packageName: current.event.packageName,
        );
        if (correlation.shouldIgnoreAsAlreadyConfirmed) {
          _recordDiagnostic(
            event: current.event,
            outcome: 'already_confirmed',
            detail: correlation.reason,
          );
          continue;
        }
        if (correlation.shouldMergeIntoExisting) {
          final existingIdx = _pendingNotifier.items
              .indexWhere((p) => p.id == correlation.matchedPendingItemId);
          if (existingIdx >= 0) {
            final existing = _pendingNotifier.items[existingIdx];
            final merged = _dedupCorrelator.mergeIntoPendingItem(
              existing: existing,
              incoming: item,
              correlation: correlation,
            );
            await _pendingNotifier.addPendingItem(merged);
            _recordDiagnostic(
              event: current.event,
              outcome: 'merged',
              detail: correlation.reason,
            );
            continue;
          }
        }
      }

      if (_autoAcceptFutureEnabled && item.isEligibleForAcceptAll) {
        await _pendingNotifier.autoAcceptIfEligible(item);
        _recordDiagnostic(
          event: current.event,
          outcome: 'auto_accepted',
          detail: 'Aprobada automáticamente (${item.category ?? 'Otros'})',
        );
      } else {
        await _pendingNotifier.addPendingItem(item);
        _recordDiagnostic(
          event: current.event,
          outcome: 'pending',
          detail:
              '${item.classification} · ${item.category ?? 'Sin cat.'} (${item.decisionSource})',
        );
      }
    }

    // Optimización RAM: al finalizar el lote, descargar Gemma local si quedó en memoria.
    if (usedAiInBatch) {
      unawaited(
        _classifier.gemmaAdapter.releaseLocalModelIfIdle().catchError((_) {}),
      );
    }
  }

  /// Elimina todos los datos locales de notificaciones (bandeja, spam, historial dedup,
  /// patrones aprendidos, patrones de spam y cola nativa).
  Future<void> wipeAllNotificationData() async {
    _batchTimer?.cancel();
    _batchTimer = null;
    _batchBuffer.clear();
    _recentCrossContext.clear();
    _diagnosticLog.clear();
    _cachedAccounts = null;
    _cachedAccountsAt = null;
    await _pendingNotifier.clearAll();
    await _patternsService.clearAll();
    if (_spamPatternsService != null) {
      await _spamPatternsService!.clearAll();
    }
    await _dedupCorrelator.clearAll();

    if (_injectedDedupBox != null) {
      await _injectedDedupBox!.clear();
    } else {
      await _boxEncryption.deleteBoxes([
        PendingTransactionsNotifier.defaultBoxName,
        PendingTransactionsNotifier.executedBoxName,
        PendingTransactionsNotifier.spamBoxName,
        LearnedPatternsService.defaultBoxName,
        SpamPatternsService.defaultBoxName,
        TransactionDedupCorrelator.defaultRulesBoxName,
        TransactionDedupCorrelator.defaultRecentMovementsBoxName,
        dedupHistoryBoxName,
      ]);
    }

    final src = _source;
    if (src is AndroidNotificationSource) {
      await src.clearNativeQueue();
    }
  }

  Future<void> dispose() async {
    _batchTimer?.cancel();
    _batchTimer = null;
    await _ingestedSubscription?.cancel();
    _ingestedSubscription = null;
    _ingestionService.detachSource();
  }
}
