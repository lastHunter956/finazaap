import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:finazaap/data/models/account_item.dart';
import '../domain/models/notification_event.dart';
import '../domain/models/notification_parse_result.dart';
import '../domain/models/pending_transaction_item.dart';
import '../domain/ports/notification_source_port.dart';
import '../presentation/notifiers/pending_transactions_notifier.dart';
import '../services/bank_whitelist_service.dart';
import '../services/learned_patterns_service.dart';
import '../services/notification_ingestion_service.dart';
import '../services/notification_parser.dart';
import '../services/transaction_classifier.dart';
import 'mock_transaction_execution_adapter.dart';

/// Implementación en memoria y simulador de [NotificationSourcePort].
///
/// Permite inyectar eventos de notificación para pruebas unitarias, desarrollo
/// y demostraciones sin requerir el servicio nativo de Android ni permisos del sistema.
class SimulatedNotificationSource implements NotificationSourcePort {
  final StreamController<NotificationEvent> _controller =
      StreamController<NotificationEvent>.broadcast();

  bool _isListening = false;

  /// Indica si el simulador está actualmente en modo de escucha.
  bool get isListening => _isListening;

  @override
  Stream<NotificationEvent> get notificationStream => _controller.stream;

  @override
  Future<NotificationSourceStatus> checkStatus() async {
    return NotificationSourceStatus(
      isListening: _isListening,
      permissionStatus: NotificationPermissionStatus.granted,
      message: _isListening
          ? 'Simulador activo y emitiendo eventos'
          : 'Simulador pausado',
    );
  }

  @override
  Future<bool> startListening() async {
    _isListening = true;
    return true;
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
  }

  /// Emite un [NotificationEvent] hacia el flujo de notificaciones.
  ///
  /// Retorna `true` si el evento fue despachado exitosamente al stream.
  /// Retorna `false` si el simulador no está escuchando o si el stream está cerrado.
  bool emit(NotificationEvent event) {
    if (!_isListening || _controller.isClosed) {
      return false;
    }
    _controller.add(event);
    return true;
  }

  /// Crea y emite un evento crudo de forma simplificada para tests y mocks.
  NotificationEvent? emitRaw({
    required String packageName,
    required String title,
    required String body,
    DateTime? timestamp,
    String? id,
  }) {
    final event = NotificationEvent(
      id: id ?? 'sim_${DateTime.now().microsecondsSinceEpoch}',
      packageName: packageName,
      title: title,
      body: body,
      timestamp: timestamp ?? DateTime.now(),
    );

    final sent = emit(event);
    return sent ? event : null;
  }

  /// Cierra el stream subyacente y libera recursos.
  Future<void> dispose() async {
    _isListening = false;
    await _controller.close();
  }
}

/// Implementación en memoria de [Box] para demostraciones de desarrollo y pruebas
/// sin escritura en disco ni acceso a las cajas reales de producción en Hive.
class InMemoryDemoBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _store = {};
  bool _isOpen = true;

  @override
  final String name;

  InMemoryDemoBox({this.name = 'in_memory_demo_box'});

  @override
  bool get isOpen => _isOpen;

  @override
  String? get path => null;

  @override
  Iterable<dynamic> get keys => _store.keys;

  @override
  Iterable<dynamic> get values => _store.values;

  @override
  int get length => _store.length;

  @override
  bool get isEmpty => _store.isEmpty;

  @override
  bool get isNotEmpty => _store.isNotEmpty;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  dynamic getAt(int index) => _store.values.elementAt(index);

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> putAt(int index, dynamic value) async {
    final key = _store.keys.elementAt(index);
    _store[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    _store.addAll(entries);
  }

  @override
  Future<void> delete(dynamic key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAt(int index) async {
    final key = _store.keys.elementAt(index);
    _store.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final key in keys) {
      _store.remove(key);
    }
  }

  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

  @override
  Future<int> clear() async {
    final count = _store.length;
    _store.clear();
    return count;
  }

  @override
  Map<dynamic, dynamic> toMap() => Map.unmodifiable(_store);

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  @override
  Future<void> deleteFromDisk() async {
    _store.clear();
    _isOpen = false;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> compact() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Construye un [PendingTransactionsNotifier] aislado en memoria con datos sintéticos
/// procesados por el pipeline real del Sprint 1 (`BankWhitelistService`,
/// `NotificationIngestionService`, `NotificationParser` y `TransactionClassifier`),
/// usando [MockTransactionExecutionAdapter] para nunca alterar saldos reales.
Future<PendingTransactionsNotifier> createDemoPendingNotifier() async {
  final pendingBox = InMemoryDemoBox(name: 'demo_pending_notifications');
  final patternsBox = InMemoryDemoBox(name: 'demo_learned_patterns');
  final patternsService = LearnedPatternsService(box: patternsBox);
  final mockExecutionAdapter = MockTransactionExecutionAdapter();

  final notifier = PendingTransactionsNotifier(
    box: pendingBox,
    learnedPatternsService: patternsService,
    executionPort: mockExecutionAdapter,
  );

  final whitelistService = BankWhitelistService();
  final ingestionService = NotificationIngestionService(
    whitelistService: whitelistService,
  );
  final parser = NotificationParser();

  final demoAccounts = <AccountItem>[
    AccountItem(
      id: 'demo-acc-1',
      icon: Icons.account_balance,
      title: 'Ahorros Bancolombia *1234',
      subtitle: 'Cuenta demo',
      balance: '0',
      iconColor: Colors.amber,
    ),
    AccountItem(
      id: 'demo-acc-2',
      icon: Icons.smartphone,
      title: 'Nequi *5678',
      subtitle: 'Billetera demo',
      balance: '0',
      iconColor: Colors.purple,
    ),
  ];

  final classifier = TransactionClassifier(
    patternsService: patternsService,
    accountsLoader: () async => demoAccounts,
  );

  final now = DateTime.now();
  final syntheticEvents = <NotificationEvent>[
    NotificationEvent(
      id: 'demo-expense-1',
      packageName: 'com.bancolombia.personas',
      title: 'Bancolombia',
      body: 'Compra aprobada por \$42.500 en EXITO COLOMBIA con tarjeta *1234',
      timestamp: now.subtract(const Duration(minutes: 5)),
    ),
    NotificationEvent(
      id: 'demo-expense-2',
      packageName: 'com.nequi.MobileApp',
      title: 'Nequi',
      body: 'Pagaste \$18.900 en JUAN VALDEZ CAFE desde tu Nequi *5678',
      timestamp: now.subtract(const Duration(minutes: 15)),
    ),
    NotificationEvent(
      id: 'demo-income-1',
      packageName: 'com.bancolombia.personas',
      title: 'Bancolombia',
      body:
          'Recibiste transferencia por \$850.000 de NOMINA EMPRESA en tu cuenta Ahorros *1234',
      timestamp: now.subtract(const Duration(minutes: 30)),
    ),
    NotificationEvent(
      id: 'demo-transfer-incomplete-1',
      packageName: 'com.bancolombia.personas',
      title: 'Bancolombia',
      body: 'Transferencia entre cuentas por \$200.000 desde cuenta *1234',
      timestamp: now.subtract(const Duration(minutes: 45)),
    ),
    NotificationEvent(
      id: 'demo-ambiguous-1',
      packageName: 'com.bancolombia.personas',
      title: 'Bancolombia',
      body: 'Cargo procesado por \$35.000 en COMERCIO VARIOS',
      timestamp: now.subtract(const Duration(hours: 1)),
    ),
    NotificationEvent(
      id: 'demo-url-1',
      packageName: 'com.bancolombia.personas',
      title: 'Bancolombia',
      body:
          'Alerta de seguridad: movimiento por \$150.000. Revisa en https://seguridad-ejemplo.invalid/validar',
      timestamp: now.subtract(const Duration(hours: 2)),
    ),
  ];

  final demoItems = <PendingTransactionItem>[];
  for (final event in syntheticEvents) {
    final ingestion = ingestionService.ingest(event, now: event.timestamp);
    if (!ingestion.isAccepted) continue;

    final parseResult = parser.parse(event);
    final rawText = '${event.title} ${event.body}'.trim();
    final classification = await classifier.classify(
      parseResult: parseResult,
      rawText: rawText,
      userAccounts: demoAccounts,
    );

    final parsed = parseResult is ParsedTransaction ? parseResult : null;

    // Preserva el caso de transferencia propia incompleta para revisión manual en UI
    final bool isIncompleteTransfer = parsed != null &&
        parsed.tipo == 'transferencia' &&
        classification.destinationAccount == null &&
        classification.classification != 'sospechosa';

    final bool forceAmbiguousReview = event.id == 'demo-ambiguous-1';

    final String effectiveClassification = isIncompleteTransfer
        ? 'transferencia-propia'
        : classification.classification;
    final String? effectiveMoneoType =
        isIncompleteTransfer ? 'Transfer' : classification.moneoType;
    final double effectiveConfidence = forceAmbiguousReview &&
            classification.confidence >= 0.85
        ? 0.62
        : classification.confidence;
    final bool effectiveRequiresReview = isIncompleteTransfer ||
        forceAmbiguousReview ||
        classification.requiresReview;

    final String? merchant = parsed?.comercio;
    final String? merchantKey =
        merchant != null && merchant.trim().isNotEmpty
            ? LearnedPatternsService.normalizeMerchant(merchant)
            : null;

    demoItems.add(
      PendingTransactionItem(
        id: 'pending-${event.id}',
        notificationId: event.id,
        rawText: event.body,
        merchantKey: merchantKey,
        comercio: merchant,
        monto: parsed?.monto,
        moneda: parsed?.moneda ?? 'COP',
        fecha: parseResult.fecha,
        classification: effectiveClassification,
        moneoType: effectiveMoneoType,
        category: classification.category,
        accountName: classification.accountName ??
            (event.packageName == 'com.nequi.MobileApp'
                ? 'Nequi *5678'
                : 'Ahorros Bancolombia *1234'),
        destinationAccount: classification.destinationAccount,
        confidence: effectiveConfidence,
        requiresReview: effectiveRequiresReview,
        autoProcessable: !effectiveRequiresReview &&
            effectiveClassification != 'sospechosa' &&
            effectiveConfidence >= 0.85,
        decisionSource: classification.decisionSource,
        flags: parseResult.flags,
        createdAt: event.timestamp,
      ),
    );
  }

  await notifier.addPendingItems(demoItems);
  await notifier.initialize();
  return notifier;
}
