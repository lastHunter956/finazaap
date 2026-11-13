import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/adapters/simulated_notification_source.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/notification_ingestion_service.dart';
import 'package:finazaap/features/notifications/services/notification_parser.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> pendingBox;
  late Box<dynamic> patternsBox;
  late LearnedPatternsService patternsService;
  late MockTransactionExecutionAdapter mockExecutionAdapter;
  late PendingTransactionsNotifier notifier;

  late SimulatedNotificationSource simulatedSource;
  late BankWhitelistService whitelistService;
  late NotificationIngestionService ingestionService;
  late NotificationParser parser;
  late TransactionClassifier classifier;

  late StreamSubscription<NotificationEvent> pipelineSubscription;

  final List<AccountItem> testUserAccounts = [
    AccountItem(
      id: 'acc_bancolombia',
      icon: Icons.account_balance,
      title: 'Ahorros Bancolombia',
      subtitle: '*1234',
      balance: '1500000',
      iconColor: Colors.blue,
    ),
    AccountItem(
      id: 'acc_nequi',
      icon: Icons.phone_android,
      title: 'Nequi',
      subtitle: '*5678',
      balance: '250000',
      iconColor: Colors.purple,
    ),
  ];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('integration_pipeline_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    pendingBox = await Hive.openBox<dynamic>('int_pending_$suffix');
    patternsBox = await Hive.openBox<dynamic>('int_patterns_$suffix');

    patternsService = LearnedPatternsService(box: patternsBox);
    mockExecutionAdapter = MockTransactionExecutionAdapter();

    notifier = PendingTransactionsNotifier(
      box: pendingBox,
      learnedPatternsService: patternsService,
      executionPort: mockExecutionAdapter,
    );
    await notifier.initialize();

    simulatedSource = SimulatedNotificationSource();
    await simulatedSource.startListening();

    whitelistService = BankWhitelistService();
    ingestionService = NotificationIngestionService(
      whitelistService: whitelistService,
    );
    ingestionService.attachSource(simulatedSource);

    parser = NotificationParser();
    classifier = TransactionClassifier(
      patternsService: patternsService,
      accountsLoader: () async => testUserAccounts,
    );

    // Conectar el flujo: Ingestión -> Parser -> Clasificador -> Bandeja de Pendientes
    pipelineSubscription =
        ingestionService.ingestedStream.listen((event) async {
      final parseResult = parser.parse(event);
      final classification = await classifier.classify(
        parseResult: parseResult,
        rawText: '${event.title}. ${event.body}',
        userAccounts: testUserAccounts,
      );

      final item = PendingTransactionItem(
        id: event.id,
        notificationId: event.id,
        rawText: '${event.title}. ${event.body}',
        merchantKey: parseResult is ParsedTransaction
            ? parseResult.comercio?.toLowerCase()
            : null,
        comercio:
            parseResult is ParsedTransaction ? parseResult.comercio : null,
        monto: parseResult is ParsedTransaction ? parseResult.monto : null,
        moneda: parseResult is ParsedTransaction ? parseResult.moneda : 'COP',
        fecha: event.timestamp,
        classification: classification.classification,
        moneoType: classification.moneoType,
        category: classification.category,
        accountName: classification.accountName,
        destinationAccount: classification.destinationAccount,
        confidence: classification.confidence,
        requiresReview: classification.requiresReview,
        autoProcessable: classification.createTransaction &&
            classification.confidence >= 0.85 &&
            !classification.requiresReview,
        decisionSource: classification.decisionSource,
        flags: parseResult.flags,
        createdAt: DateTime.now(),
      );

      await notifier.addPendingItem(item);
    });
  });

  tearDown(() async {
    await pipelineSubscription.cancel();
    ingestionService.dispose();
    await simulatedSource.dispose();

    if (pendingBox.isOpen) {
      await pendingBox.clear();
      await pendingBox.close();
    }
    if (patternsBox.isOpen) {
      await patternsBox.clear();
      await patternsBox.close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group(
      'Flujo de Integración End-to-End: Ingesta -> Parseo -> Clasificación -> Bandeja',
      () {
    test(
        'Pipeline procesa compras e ingresos legítimos, bloquea phishing, '
        'ignora apps no autorizadas y filtra duplicados temporales', () async {
      final now = DateTime.now();

      // 1. Notificación legítima de compra en Bancolombia (Whitelisted)
      simulatedSource.emit(
        NotificationEvent(
          id: 'event_bancolombia_purchase',
          packageName: 'com.bancolombia.personas',
          title: 'Bancolombia le informa',
          body: 'Compra por \$45.000 en Exito Laureles con su tarjeta *1234.',
          timestamp: now,
        ),
      );

      // 2. Notificación legítima de ingreso en Nequi (Whitelisted)
      simulatedSource.emit(
        NotificationEvent(
          id: 'event_nequi_income',
          packageName: 'com.nequi.MobileApp',
          title: '¡Te llegó plata!',
          body: 'Te enviaron \$80.000 a tu Nequi.',
          timestamp: now,
        ),
      );

      // 3. Notificación con intento de phishing y urgencia en Davivienda (Whitelisted pero maliciosa)
      simulatedSource.emit(
        NotificationEvent(
          id: 'event_phishing_alert',
          packageName: 'com.davivienda.billetera',
          title: 'Davivienda Alerta',
          body:
              'Tu cuenta fue bloqueada. Actualiza tus datos de inmediato en bit.ly/davi-seguridad para evitar cobros.',
          timestamp: now,
        ),
      );

      // 4. Notificación de app no autorizada (Fuera de Whitelist)
      simulatedSource.emit(
        NotificationEvent(
          id: 'event_whatsapp_spam',
          packageName: 'com.whatsapp',
          title: 'Mensaje de chat',
          body: 'Te envié \$50.000 al banco.',
          timestamp: now,
        ),
      );

      // 5. Notificación idéntica a la 1 dentro de los 5 minutos (Duplicado)
      simulatedSource.emit(
        NotificationEvent(
          id: 'event_bancolombia_duplicate',
          packageName: 'com.bancolombia.personas',
          title: 'Bancolombia le informa',
          body: 'Compra por \$45.000 en Exito Laureles con su tarjeta *1234.',
          timestamp: now,
        ),
      );

      // Esperar brevemente a que el stream asíncrono complete
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // Verificación de la capa de Ingestión:
      // De 5 eventos: 3 aceptados, 1 descartado por no-whitelist, 1 descartado por duplicado
      expect(ingestionService.ingestedCount, equals(3));
      expect(ingestionService.discardedNonWhitelistedCount, equals(1));
      expect(ingestionService.discardedDuplicatesCount, equals(1));

      // Verificación de la Bandeja de Pendientes:
      // Exactamente 3 ítems llegaron a la bandeja
      expect(notifier.count, equals(3));
      expect(notifier.eligibleCount, equals(2));

      final items = notifier.items;
      final exitoItem = items.firstWhere(
        (i) => i.id == 'event_bancolombia_purchase',
      );
      final nequiItem = items.firstWhere(
        (i) => i.id == 'event_nequi_income',
      );
      final phishingItem = items.firstWhere(
        (i) => i.id == 'event_phishing_alert',
      );

      // 1. Compra Exito: clasificada como gasto con alta confianza
      expect(exitoItem.classification, equals('gasto'));
      expect(exitoItem.monto, equals(45000.0));
      expect(exitoItem.confidence, greaterThanOrEqualTo(0.85));
      expect(exitoItem.requiresReview, isFalse);

      // 2. Ingreso Nequi: clasificado como ingreso con alta confianza
      expect(nequiItem.classification, equals('ingreso'));
      expect(nequiItem.monto, equals(80000.0));
      expect(nequiItem.confidence, greaterThanOrEqualTo(0.85));
      expect(nequiItem.requiresReview, isFalse);

      // 3. Phishing: clasificado como sospechosa, bloqueo de saldos
      expect(phishingItem.classification, equals('sospechosa'));
      expect(phishingItem.confidence, equals(0.0));
      expect(phishingItem.requiresReview, isTrue);

      // Invariante de Aislamiento de Saldos: Ninguna transacción se ha ejecutado aún
      expect(mockExecutionAdapter.executionCount, equals(0));

      // Ejecutar Aprobación Masiva ("Aceptar todo")
      final summary = await notifier.acceptAll();

      expect(summary.acceptedCount, equals(2));
      expect(summary.remainingCount, equals(1));
      expect(mockExecutionAdapter.executionCount, equals(2));

      // Verificar transacciones ejecutadas en el puerto
      final executedAmounts =
          mockExecutionAdapter.executedRequests.map((r) => r.amount).toList();
      expect(executedAmounts, containsAll([45000.0, 80000.0]));

      // El ítem sospechoso sigue en la bandeja
      expect(notifier.count, equals(1));
      expect(notifier.items.first.id, equals('event_phishing_alert'));

      // Intentar confirmar directamente el sospechoso falla
      final confirmSuspicious =
          await notifier.confirmItem('event_phishing_alert');
      expect(confirmSuspicious, isFalse);
      expect(mockExecutionAdapter.executionCount, equals(2));

      // Descartar el ítem sospechoso
      final discardSuccess = await notifier.discardItem('event_phishing_alert');
      expect(discardSuccess, isTrue);
      expect(notifier.count, equals(0));

      // Verificación final del Feedback Loop (learned_patterns):
      // Se aprendió el patrón de Exito Laureles
      final learnedExito = await patternsService.findPattern('Exito Laureles');
      expect(learnedExito, isNotNull);
      expect(learnedExito!.confirmations, equals(1));

      // No se guardó ningún patrón para el SMS de phishing
      final allPatterns = await patternsService.getAllPatterns();
      expect(
        allPatterns.any((p) =>
            p.merchantKey.contains('davivienda') ||
            p.merchantKey.contains('seguridad')),
        isFalse,
      );
    });
  });
}
