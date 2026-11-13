import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/presentation/screens/pending_transactions_screen.dart';
import 'package:finazaap/features/notifications/presentation/widgets/pending_transaction_card.dart';
import 'package:finazaap/features/notifications/presentation/widgets/suspicious_badge.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';

/// Implementación en memoria de [Box] para pruebas de widgets sin E/S de disco
/// y compatible con el scheduler síncrono/falso de [FakeAsync].
class _InMemoryHiveBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _store = {};
  bool _isOpen = true;

  @override
  bool get isOpen => _isOpen;

  @override
  String get name => 'in_memory_box';

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

void main() {
  late _InMemoryHiveBox pendingBox;
  late _InMemoryHiveBox patternsBox;
  late LearnedPatternsService patternsService;
  late MockTransactionExecutionAdapter mockExecutionAdapter;
  late PendingTransactionsNotifier notifier;

  setUp(() async {
    pendingBox = _InMemoryHiveBox();
    patternsBox = _InMemoryHiveBox();

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
    await pendingBox.clear();
    await patternsBox.clear();
  });

  PendingTransactionItem createItem({
    required String id,
    required String comercio,
    required double monto,
    required String classification,
    String? category,
    String? accountName,
    String? destinationAccount,
    required double confidence,
    required bool requiresReview,
    List<String> flags = const [],
  }) {
    return PendingTransactionItem(
      id: id,
      rawText: 'Compra en $comercio por \$$monto',
      merchantKey: comercio.toLowerCase(),
      comercio: comercio,
      monto: monto,
      fecha: DateTime(2026, 11, 13, 11, 0),
      classification: classification,
      category: category ?? 'Otros',
      accountName: accountName,
      destinationAccount: destinationAccount,
      confidence: confidence,
      requiresReview: requiresReview,
      autoProcessable: !requiresReview && confidence >= 0.85,
      decisionSource: 'deterministic_rules',
      flags: flags,
      createdAt: DateTime(2026, 11, 13, 11, 0),
    );
  }

  Widget createTestWidget() {
    return MaterialApp(
      home: PendingTransactionsScreen(notifier: notifier),
    );
  }

  group('PendingTransactionsScreen - Interacción Completa de Bandeja', () {
    testWidgets(
      'Bandeja mixta: "Aceptar todo" solo aprueba los 2 de alta confianza, '
      'mantiene baja confianza y sospechosa para revisión manual',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Alta confianza A
        final itemA = createItem(
          id: 'item_a',
          comercio: 'Supermercado Exito',
          monto: 50000.0,
          classification: 'gasto',
          category: 'Alimentación',
          accountName: 'Bancolombia Ahorros',
          confidence: 0.95,
          requiresReview: false,
        );

        // 2. Alta confianza B
        final itemB = createItem(
          id: 'item_b',
          comercio: 'Nomina Empresa',
          monto: 200000.0,
          classification: 'ingreso',
          category: 'Salario',
          accountName: 'Nequi',
          confidence: 0.90,
          requiresReview: false,
        );

        // 3. Baja confianza C
        final itemC = createItem(
          id: 'item_c',
          comercio: 'Cafeteria Central',
          monto: 8500.0,
          classification: 'gasto',
          category: 'Otros',
          accountName: 'Bancolombia Ahorros',
          confidence: 0.65,
          requiresReview: true,
        );

        // 4. Sospechosa D
        final itemD = createItem(
          id: 'item_d',
          comercio: 'Banco Alerta Phishing',
          monto: 1000000.0,
          classification: 'sospechosa',
          category: 'Fraude',
          accountName: null,
          confidence: 0.0,
          requiresReview: true,
          flags: ['anti_fraud_link_detected'],
        );

        await notifier.addPendingItems([itemA, itemB, itemC, itemD]);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Verificar que los 4 comercios se renderizan en tarjetas
        expect(find.byType(PendingTransactionCard), findsNWidgets(4));
        expect(find.text('Supermercado Exito'), findsOneWidget);
        expect(find.text('Nomina Empresa'), findsOneWidget);
        expect(find.text('Cafeteria Central'), findsOneWidget);
        expect(find.text('Banco Alerta Phishing'), findsOneWidget);

        // Verificar insignias
        expect(find.byType(SuspiciousBadge), findsNWidgets(4));
        expect(find.text('Sospechosa'), findsOneWidget);

        // Pulsa "Aceptar todo"
        expect(find.text('Aceptar todo'), findsOneWidget);
        await tester.tap(find.text('Aceptar todo'));
        await tester.pumpAndSettle();

        // Los 2 de alta confianza se confirmaron y salieron de la bandeja
        expect(find.text('Supermercado Exito'), findsNothing);
        expect(find.text('Nomina Empresa'), findsNothing);

        // Los 2 restantes permanecen visibles en pantalla
        expect(find.text('Cafeteria Central'), findsOneWidget);
        expect(find.text('Banco Alerta Phishing'), findsOneWidget);
        expect(find.byType(PendingTransactionCard), findsNWidgets(2));

        // Verificar que mockExecutionAdapter ejecutó exactamente 2 transacciones
        expect(mockExecutionAdapter.executionCount, equals(2));

        // Verificar que learned_patterns actualizó exactamente los 2 de alta confianza
        final allPatterns = await patternsService.getAllPatterns();
        expect(allPatterns.length, equals(2));
        final patternKeys = allPatterns.map((p) => p.merchantKey).toList();
        expect(
            patternKeys, containsAll(['supermercado exito', 'nomina empresa']));

        // Feedback al usuario con SnackBar
        expect(find.textContaining('Se aceptaron 2 transacciones'),
            findsOneWidget);

        // Pulsa "Corregir" en el ítem de baja confianza ('Cafeteria Central')
        final correctButtons = find.widgetWithText(OutlinedButton, 'Corregir');
        expect(correctButtons, findsNWidgets(2));
        await tester.tap(correctButtons.first);
        await tester.pumpAndSettle();

        // El diálogo modal de corrección está abierto
        expect(find.text('Corregir Transacción'), findsOneWidget);

        // Guardar la corrección
        await tester.tap(find.text('Guardar corrección'));
        await tester.pumpAndSettle();

        // Cafeteria Central fue confirmada y desaparece de la bandeja
        expect(find.text('Cafeteria Central'), findsNothing);
        expect(find.byType(PendingTransactionCard), findsNWidgets(1));
        expect(mockExecutionAdapter.executionCount, equals(3));

        // Learned patterns ahora tiene 3 registros
        final patternsAfterCorrection = await patternsService.getAllPatterns();
        expect(patternsAfterCorrection.length, equals(3));

        // Pulsa "Descartar" en el ítem sospechoso ('Banco Alerta Phishing')
        final discardButton = find.widgetWithText(TextButton, 'Descartar');
        expect(discardButton, findsOneWidget);
        await tester.tap(discardButton);
        await tester.pumpAndSettle();

        // La bandeja queda vacía
        expect(find.text('Banco Alerta Phishing'), findsNothing);
        expect(find.byType(PendingTransactionCard), findsNothing);
        expect(find.text('No hay transacciones pendientes'), findsOneWidget);

        // Descartar no ejecutó ninguna transacción adicional ni guardó patrón
        expect(mockExecutionAdapter.executionCount, equals(3));
        final finalPatterns = await patternsService.getAllPatterns();
        expect(finalPatterns.length, equals(3));
        expect(
          finalPatterns.any((p) => p.merchantKey.contains('phishing')),
          isFalse,
        );
      },
    );
  });
}
