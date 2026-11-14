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
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/notification_ingestion_service.dart';
import 'package:finazaap/features/notifications/services/notification_parser.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';

/// Coordinador del pipeline real de notificaciones bancarias en Moneo.
///
/// Conecta:
/// Fuente (Android / puerto inyectado) -> Whitelist + Dedup -> Parser ->
/// Clasificador jerárquico -> Bandeja cifrada (`PendingTransactionsNotifier`) ->
/// Contabilidad real (`RealTransactionExecutionAdapter`).
class NotificationPipelineService {
  static const String captureEnabledPrefsKey = 'notifications_capture_enabled';
  static const String autoAcceptFuturePrefsKey =
      'notifications_auto_accept_future';
  static const String dedupHistoryBoxName = 'notification_dedup_history';

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
  }) {
    if (boxEncryption == null &&
        whitelistService == null &&
        source == null &&
        executionPort == null &&
        dedupBox == null &&
        pendingBox == null &&
        executedBox == null &&
        patternsBox == null) {
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
        _injectedPatternsBox = null {
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
  })  : _boxEncryption = boxEncryption ?? NotificationBoxEncryption(),
        _whitelistService = whitelistService ?? BankWhitelistService(),
        _source = source ?? AndroidNotificationSource(),
        _executionPort = executionPort ?? RealTransactionExecutionAdapter(),
        _injectedDedupBox = dedupBox,
        _injectedPendingBox = pendingBox,
        _injectedExecutedBox = executedBox,
        _injectedPatternsBox = patternsBox {
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

  late final NotificationIngestionService _ingestionService;
  late final NotificationParser _parser;
  late final LearnedPatternsService _patternsService;
  late final TransactionClassifier _classifier;
  late final PendingTransactionsNotifier _pendingNotifier;

  StreamSubscription<NotificationEvent>? _ingestedSubscription;
  Future<void> _processingChain = Future<void>.value();
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
    _classifier = TransactionClassifier(
      patternsService: _patternsService,
    );
    _pendingNotifier = PendingTransactionsNotifier(
      box: _injectedPendingBox,
      executedBox: _injectedExecutedBox,
      boxEncryption: _injectedPendingBox == null ? _boxEncryption : null,
      learnedPatternsService: _patternsService,
      executionPort: _executionPort,
    );
  }

  BankWhitelistService get whitelistService => _whitelistService;
  NotificationSourcePort get source => _source;
  LearnedPatternsService get patternsService => _patternsService;
  PendingTransactionsNotifier get pendingNotifier => _pendingNotifier;
  bool get isCaptureEnabled => _captureEnabled;
  bool get isAutoAcceptFutureEnabled => _autoAcceptFutureEnabled;

  Future<void> initialize() async {
    if (_initialized) return;

    await _whitelistService.loadFromPrefs();
    final prefs = await SharedPreferences.getInstance();
    _captureEnabled = prefs.getBool(captureEnabledPrefsKey) ?? false;
    _autoAcceptFutureEnabled = prefs.getBool(autoAcceptFuturePrefsKey) ?? false;

    try {
      await _pendingNotifier.initialize();
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

  /// Drena eventos acumulados cuando la app regresa a primer plano.
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
  }

  Future<Box<dynamic>> _getDedupBox() async {
    if (_injectedDedupBox != null) return _injectedDedupBox!;
    return _boxEncryption.openEncryptedBox(dedupHistoryBoxName);
  }

  /// Espera a que termine cualquier evento actualmente en la cola de procesamiento.
  Future<void> flushPendingProcessing() => _processingChain;

  void _enqueueEvent(NotificationEvent event) {
    _processingChain = _processingChain
        .then((_) => _processIngestedEvent(event))
        .catchError((_) {});
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

  Future<void> _processIngestedEvent(NotificationEvent event) async {
    final dedupHash = _ingestionService.computeDedupHash(event);
    final dedupBox = await _getDedupBox();

    // Deduplicación persistente entre reinicios (ventana de 5 min)
    if (dedupBox.containsKey(dedupHash)) {
      return;
    }
    await dedupBox.put(dedupHash, event.timestamp.toIso8601String());

    final parseResult = _parser.parse(event);
    if (parseResult is UnparseableNotification) {
      return;
    }

    final rawText = [event.title.trim(), event.body.trim()]
        .where((s) => s.isNotEmpty)
        .join('. ');

    final accounts = await _getRecentAccounts();
    final classification = await _classifier.classify(
      parseResult: parseResult,
      rawText: rawText,
      userAccounts: accounts,
      packageName: event.packageName,
    );

    final double? amount =
        parseResult is ParsedTransaction ? parseResult.monto : null;
    final String currency =
        parseResult is ParsedTransaction ? parseResult.moneda : 'COP';
    final String? merchant =
        parseResult is ParsedTransaction ? parseResult.comercio : null;

    final item = PendingTransactionItem(
      id: 'notif_$dedupHash',
      notificationId: event.id,
      rawText: rawText,
      merchantKey:
          merchant != null ? LearnedPatternsService.normalizeMerchant(merchant) : null,
      comercio: merchant ?? _whitelistService.getBankName(event.packageName),
      monto: amount,
      moneda: currency,
      fecha: parseResult.fecha,
      classification: classification.classification,
      moneoType: classification.moneoType,
      category: classification.category,
      accountName: classification.accountName,
      destinationAccount: classification.destinationAccount,
      confidence: parseResult.confidence < classification.confidence
          ? parseResult.confidence
          : classification.confidence,
      requiresReview: parseResult.requiresReview || classification.requiresReview,
      autoProcessable: !(parseResult.requiresReview || classification.requiresReview) &&
          classification.classification != 'sospechosa',
      decisionSource: classification.decisionSource,
      flags: parseResult.flags,
      createdAt: DateTime.now(),
    );

    if (_autoAcceptFutureEnabled && item.isEligibleForAcceptAll) {
      await _pendingNotifier.autoAcceptIfEligible(item);
    } else {
      await _pendingNotifier.addPendingItem(item);
    }
  }

  /// Elimina todos los datos locales de notificaciones (bandeja, historial dedup,
  /// patrones aprendidos y cola nativa).
  Future<void> wipeAllNotificationData() async {
    _cachedAccounts = null;
    _cachedAccountsAt = null;
    await _pendingNotifier.clearAll();
    await _patternsService.clearAll();

    if (_injectedDedupBox != null) {
      await _injectedDedupBox!.clear();
    } else {
      await _boxEncryption.deleteBoxes([
        PendingTransactionsNotifier.defaultBoxName,
        PendingTransactionsNotifier.executedBoxName,
        LearnedPatternsService.defaultBoxName,
        dedupHistoryBoxName,
      ]);
    }

    final src = _source;
    if (src is AndroidNotificationSource) {
      await src.clearNativeQueue();
    }
  }

  Future<void> dispose() async {
    await _ingestedSubscription?.cancel();
    _ingestedSubscription = null;
    _ingestionService.detachSource();
  }
}
