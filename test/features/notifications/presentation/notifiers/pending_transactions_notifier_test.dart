import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> pendingBox;
  late Box<dynamic> patternsBox;
  late LearnedPatternsService patternsService;
  late MockTransactionExecutionAdapter mockExecutionAdapter;
  late PendingTransactionsNotifier notifier;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pending_notifier_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    pendingBox = await Hive.openBox<dynamic>('test_pending_$suffix');
    patternsBox = await Hive.openBox<dynamic>('test_patterns_$suffix');

    patternsService = LearnedPatternsService(box: patternsBox);
    mockExecutionAdapter = MockTransactionExecutionAdapter();

    notifier = PendingTransactionsNotifier(
      box: pendingBox,
      learnedPatternsService: patternsService,
      executionPort: mockExecutionAdapter,
    );
    await notifier.initialize();
  });

  tearDown(() async {
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

  PendingTransactionItem createItem({
    required String id,
    String? comercio,
    double monto = 50000.0,
    String classification = 'gasto',
    String? moneoType,
    String? category = 'Alimentación',
    String? accountName = 'Ahorros *4821',
    String? destinationAccount,
    double confidence = 0.95,
    bool requiresReview = false,
    List<String> flags = const [],
  }) {
    return PendingTransactionItem(
      id: id,
      rawText: 'Compra en $comercio por \$$monto',
      merchantKey: comercio?.toLowerCase(),
      comercio: comercio,
      monto: monto,
      fecha: DateTime(2026, 11, 13, 10, 30),
      classification: classification,
      moneoType: moneoType,
      category: category,
      accountName: accountName,
      destinationAccount: destinationAccount,
      confidence: confidence,
      requiresReview: requiresReview,
      autoProcessable: !requiresReview && confidence >= 0.85,
      decisionSource: 'deterministic_rules',
      flags: flags,
      createdAt: DateTime(2026, 11, 13, 10, 30),
    );
  }

  group('PendingTransactionsNotifier - Invariante de Aislamiento de Saldos',
      () {
    test(
        'Agregar transacciones a la bandeja no invoca TransactionExecutionPort',
        () async {
      final item = createItem(id: 'tx_1', comercio: 'Exito');
      await notifier.addPendingItem(item);

      expect(notifier.count, equals(1));
      expect(mockExecutionAdapter.executionCount, equals(0));
      expect(pendingBox.containsKey('tx_1'), isTrue);
    });

    test('Persistencia se recarga fielmente al reinicializar la bandeja',
        () async {
      await notifier.addPendingItem(
        createItem(id: 'tx_1', comercio: 'Exito', monto: 80000.0),
      );
      await notifier.addPendingItem(
        createItem(id: 'tx_2', comercio: 'D1', monto: 25000.0),
      );

      final reloadedNotifier = PendingTransactionsNotifier(
        box: pendingBox,
        learnedPatternsService: patternsService,
        executionPort: mockExecutionAdapter,
      );
      await reloadedNotifier.initialize();

      expect(reloadedNotifier.count, equals(2));
      expect(reloadedNotifier.items.map((i) => i.id),
          containsAll(['tx_1', 'tx_2']));
    });
  });

  group('PendingTransactionsNotifier - Filtro Estricto de "Aceptar Todo"', () {
    test(
        '"Aceptar todo" procesa exclusivamente ítems elegibles de alta confianza',
        () async {
      // 1. Alta confianza gasto (Elegible)
      final item1 = createItem(
        id: 'tx_high_1',
        comercio: 'Exito Laureles',
        confidence: 0.95,
        requiresReview: false,
        classification: 'gasto',
        accountName: 'Ahorros *4821',
      );

      // 2. Alta confianza ingreso (Elegible)
      final item2 = createItem(
        id: 'tx_high_2',
        comercio: 'Empresa Nómina',
        confidence: 0.90,
        requiresReview: false,
        classification: 'ingreso',
        moneoType: 'Income',
        accountName: 'Nequi',
      );

      // 3. Baja confianza (No elegible: confidence < 0.85 y requiresReview)
      final item3 = createItem(
        id: 'tx_low',
        comercio: 'Tienda Esquina',
        confidence: 0.65,
        requiresReview: true,
        classification: 'gasto',
        accountName: 'Ahorros *4821',
      );

      // 4. Sospechosa (No elegible: clasificación sospechosa)
      final item4 = createItem(
        id: 'tx_suspicious',
        comercio: 'Banco Phishing Alert',
        confidence: 0.0,
        requiresReview: true,
        classification: 'sospechosa',
        accountName: null,
        flags: ['anti_fraud_link_detected'],
      );

      // 5. Transferencia propia sin cuenta destino (No elegible)
      final item5 = createItem(
        id: 'tx_transfer_incomplete',
        comercio: 'Transferencia',
        confidence: 0.95,
        requiresReview: false,
        classification: 'transferencia-propia',
        accountName: 'Ahorros *4821',
        destinationAccount: null,
      );

      await notifier.addPendingItems([item1, item2, item3, item4, item5]);
      expect(notifier.count, equals(5));
      expect(notifier.eligibleCount, equals(2));

      final summary = await notifier.acceptAll();

      expect(summary.acceptedCount, equals(2));
      expect(summary.remainingCount, equals(3));
      expect(mockExecutionAdapter.executionCount, equals(2));

      // Verificar que los ítems no elegibles siguen en la bandeja
      final remainingIds = notifier.items.map((i) => i.id).toList();
      expect(remainingIds,
          containsAll(['tx_low', 'tx_suspicious', 'tx_transfer_incomplete']));
      expect(remainingIds.contains('tx_high_1'), isFalse);
      expect(remainingIds.contains('tx_high_2'), isFalse);

      // Verificar que learned_patterns fue actualizado para los 2 ítems aceptados
      final patternExito = await patternsService.findPattern('Exito Laureles');
      expect(patternExito, isNotNull);
      expect(patternExito!.confirmations, equals(1));

      final patternNomina = await patternsService.findPattern('Empresa Nómina');
      expect(patternNomina, isNotNull);
      expect(patternNomina!.confirmations, equals(1));
    });
  });

  group('PendingTransactionsNotifier - Acciones Individuales y Feedback Loop',
      () {
    test(
        'Confirmar ítem válido ejecuta transacción y actualiza learned_patterns',
        () async {
      final item = createItem(
        id: 'tx_valid',
        comercio: 'Restaurante Central',
        category: 'Alimentación',
        accountName: 'Ahorros Bancolombia',
      );
      await notifier.addPendingItem(item);

      final success = await notifier.confirmItem('tx_valid');

      expect(success, isTrue);
      expect(notifier.count, equals(0));
      expect(mockExecutionAdapter.executionCount, equals(1));
      expect(mockExecutionAdapter.lastExecutedRequest?.accountName,
          equals('Ahorros Bancolombia'));
      expect(mockExecutionAdapter.lastExecutedRequest?.detail,
          equals('Restaurante Central'));

      final pattern = await patternsService.findPattern('Restaurante Central');
      expect(pattern, isNotNull);
      expect(pattern!.category, equals('Alimentación'));
      expect(pattern.confirmations, equals(1));
    });

    test('Confirmar directamente un ítem "sospechosa" es rechazado', () async {
      final item = createItem(
        id: 'tx_fraud',
        comercio: 'Phishing SMS',
        classification: 'sospechosa',
        confidence: 0.0,
        requiresReview: true,
      );
      await notifier.addPendingItem(item);

      final success = await notifier.confirmItem('tx_fraud');

      expect(success, isFalse);
      expect(notifier.count, equals(1));
      expect(mockExecutionAdapter.executionCount, equals(0));
      expect(notifier.errorMessage, contains('sospechosa'));
    });

    test('Corregir ítem ejecuta transacción corregida y registra corrección',
        () async {
      final item = createItem(
        id: 'tx_to_correct',
        comercio: 'Uber Trip',
        category: 'Otros',
        classification: 'gasto',
        confidence: 0.60,
        requiresReview: true,
      );
      await notifier.addPendingItem(item);

      final success = await notifier.correctItem(
        id: 'tx_to_correct',
        newClassification: 'gasto',
        newCategory: 'Transporte',
        newAccountName: 'Tarjeta Crédito',
        newAmount: 32000.0,
      );

      expect(success, isTrue);
      expect(notifier.count, equals(0));
      expect(mockExecutionAdapter.executionCount, equals(1));
      expect(mockExecutionAdapter.lastExecutedRequest?.amount, equals(32000.0));
      expect(mockExecutionAdapter.lastExecutedRequest?.accountName,
          equals('Tarjeta Crédito'));

      final pattern = await patternsService.findPattern('Uber Trip');
      expect(pattern, isNotNull);
      expect(pattern!.category, equals('Transporte'));
      expect(pattern.accountName, equals('Tarjeta Crédito'));
      expect(pattern.lastCorrectedAt, isNotNull);
    });

    test(
        'Descartar ítem remueve de la bandeja sin tocar saldos ni learned_patterns',
        () async {
      final item = createItem(
        id: 'tx_to_discard',
        comercio: 'Spam Comercial',
      );
      await notifier.addPendingItem(item);

      final success = await notifier.discardItem('tx_to_discard');

      expect(success, isTrue);
      expect(notifier.count, equals(0));
      expect(mockExecutionAdapter.executionCount, equals(0));

      final pattern = await patternsService.findPattern('Spam Comercial');
      expect(pattern, isNull);
    });
  });
}
