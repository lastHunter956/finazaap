import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/adapters/simulated_notification_source.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/presentation/screens/pending_transactions_screen.dart';
import 'package:finazaap/features/notifications/presentation/widgets/pending_transaction_card.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';

void main() {
  late InMemoryDemoBox pendingBox;
  late InMemoryDemoBox patternsBox;
  late LearnedPatternsService patternsService;
  late MockTransactionExecutionAdapter executionAdapter;
  late PendingTransactionsNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'gastos': [
        jsonEncode({'text': 'Alimentación', 'icon': 0xe532, 'color': 0xFF2196F3}),
        jsonEncode({'text': 'Otros', 'icon': 0xe148, 'color': 0xFF9E9E9E}),
      ],
      'ingresos': [
        jsonEncode({'text': 'Otros', 'icon': 0xe148, 'color': 0xFF9E9E9E}),
      ],
    });
    await ThemeNotifier.init();
    pendingBox = InMemoryDemoBox();
    patternsBox = InMemoryDemoBox();
    patternsService = LearnedPatternsService(box: patternsBox);
    executionAdapter = MockTransactionExecutionAdapter();
    notifier = PendingTransactionsNotifier(
      box: pendingBox,
      learnedPatternsService: patternsService,
      executionPort: executionAdapter,
    );
    await notifier.initialize();
  });

  tearDown(() async {
    await pendingBox.clear();
    await patternsBox.clear();
  });

  PendingTransactionItem makeItem({
    required String id,
    required String comercio,
    required double monto,
    String channel = 'app',
    String? strategicNote,
    List<Map<String, dynamic>> groupedEvents = const [],
  }) {
    return PendingTransactionItem(
      id: id,
      rawText: 'Compra en $comercio por \$$monto',
      merchantKey: comercio.toLowerCase(),
      comercio: comercio,
      monto: monto,
      fecha: DateTime(2026, 11, 17, 10, 30),
      classification: 'gasto',
      category: 'Alimentación',
      accountName: 'Bancolombia',
      confidence: 0.92,
      requiresReview: false,
      autoProcessable: true,
      decisionSource: 'learned_patterns',
      createdAt: DateTime(2026, 11, 17, 10, 30),
      channel: channel,
      groupedEvents: groupedEvents,
      strategicNote: strategicNote,
    );
  }

  group('PendingTransactionCard & Bandeja Agrupada', () {
    testWidgets(
      'renderiza strategicNote, badge Agrupada (N avisos) y botón Separar en 360x640 @ 1.35x sin overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var splitCalled = false;
        final child1 = makeItem(id: 'c1', comercio: 'Éxito', monto: 45000);
        final child2 = makeItem(
          id: 'c2',
          comercio: 'Éxito',
          monto: 45000,
          channel: 'sms',
        );
        final child3 = makeItem(
          id: 'c3',
          comercio: 'Éxito',
          monto: 45000,
          channel: 'correo',
        );

        final grouped = makeItem(
          id: 'g1',
          comercio: 'Éxito',
          monto: 45000,
          strategicNote:
              'Agrupamos 3 avisos del mismo cobro; llevas 25% de tu gasto mensual en Alimentación.',
          groupedEvents: [
            child1.toJson(),
            child2.toJson(),
            child3.toJson(),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(ThemeNotifier.activeMode),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.35),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PendingTransactionCard(
                    item: grouped,
                    onConfirm: () {},
                    onCorrect: () {},
                    onDiscard: () {},
                    onSplit: () => splitCalled = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Agrupada (3 avisos)'), findsOneWidget);
        expect(find.text('Separar'), findsOneWidget);
        expect(
          find.textContaining('Agrupamos 3 avisos del mismo cobro'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Separar'));
        await tester.pump();
        expect(splitCalled, isTrue);
      },
    );

    testWidgets(
      'flujo de selección múltiple: Agrupar en 1 fusiona ítems y Separar los restaura',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final item1 = makeItem(
          id: 'p1',
          comercio: 'D1',
          monto: 22000,
          strategicNote: 'Coincide con tu patrón habitual.',
        );
        final item2 = makeItem(
          id: 'p2',
          comercio: 'D1 SMS',
          monto: 22000,
          channel: 'sms',
        );
        await notifier.addPendingItems([item1, item2]);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(ThemeNotifier.activeMode),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.35),
              ),
              child: PendingTransactionsScreen(notifier: notifier),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(notifier.count, 2);
        expect(find.byKey(const Key('toggle_selection_mode_button')), findsOneWidget);

        // Activar modo selección
        await tester.tap(find.byKey(const Key('toggle_selection_mode_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('merge_selected_button')), findsOneWidget);

        // Seleccionar los 2 ítems
        await tester.tap(find.byKey(const ValueKey('select_pending_p1')));
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('select_pending_p2')),
          200,
        );
        await tester.tap(find.byKey(const ValueKey('select_pending_p2')));
        await tester.pumpAndSettle();

        // Agrupar en 1
        await tester.tap(find.byKey(const Key('merge_selected_button')));
        await tester.pumpAndSettle();

        expect(notifier.count, 1);
        expect(find.text('Agrupada (2 avisos)'), findsOneWidget);
        expect(find.text('Separar'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Separar de nuevo
        await tester.tap(find.text('Separar'));
        await tester.pumpAndSettle();

        expect(notifier.count, 2);
        expect(find.text('Agrupada (2 avisos)'), findsNothing);
      },
    );
  });
}
