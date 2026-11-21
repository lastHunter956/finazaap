import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/domain/models/spam_models.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/presentation/screens/pending_transactions_screen.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/spam_patterns_service.dart';

class _InMemoryBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _store = {};

  @override
  bool get isOpen => true;
  @override
  int get length => _store.length;
  @override
  Iterable<dynamic> get keys => _store.keys.toList();
  @override
  Iterable<dynamic> get values => _store.values.toList();
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => _store[key] = value;
  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async =>
      _store.addAll(entries);
  @override
  Future<void> delete(dynamic key) async => _store.remove(key);
  @override
  Future<int> clear() async {
    final len = _store.length;
    _store.clear();
    return len;
  }

  @override
  Future<void> compact() async {}
  @override
  bool containsKey(dynamic key) => _store.containsKey(key);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Pestaña Spam muestra avisos con retención de 5 días, permite Confirmar spam y rescatar a Pendientes',
    (tester) async {
      final pendingBox = _InMemoryBox();
      final spamBox = _InMemoryBox();
      final dismissedBox = _InMemoryBox();
      final patternsBox = _InMemoryBox();

      final spamPatternsService = SpamPatternsService(box: dismissedBox);
      final notifier = PendingTransactionsNotifier(
        box: pendingBox,
        spamBox: spamBox,
        learnedPatternsService: LearnedPatternsService(box: patternsBox),
        spamPatternsService: spamPatternsService,
        executionPort: MockTransactionExecutionAdapter(),
      );

      final now = DateTime.now();
      await notifier.addSpamItem(
        SpamNotificationItem(
          id: 'spam_1',
          item: PendingTransactionItem(
            id: 'spam_1',
            rawText: 'Rappi. ¡Gana \$20.000 en tu próximo pedido!',
            comercio: 'Rappi',
            monto: 20000,
            fecha: now,
            classification: 'spam',
            confidence: 0.92,
            requiresReview: false,
            autoProcessable: false,
            decisionSource: 'ai_spam',
            createdAt: now,
            packageName: 'com.grability.rappi',
          ),
          spamReason: 'Promoción detectada por IA',
          spamSource: 'ai_spam',
          detectedAt: now,
        ),
      );
      await notifier.addSpamItem(
        SpamNotificationItem(
          id: 'spam_2',
          item: PendingTransactionItem(
            id: 'spam_2',
            rawText: 'Rappi. Compra aprobada \$38.000 en El Corral',
            comercio: 'El Corral',
            monto: 38000,
            fecha: now,
            classification: 'spam',
            confidence: 0.85,
            requiresReview: false,
            autoProcessable: false,
            decisionSource: 'learned_spam',
            createdAt: now,
            packageName: 'com.grability.rappi',
          ),
          spamReason: 'Patrón marcado como spam',
          spamSource: 'learned_spam',
          detectedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PendingTransactionsScreen(notifier: notifier),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir la vista Spam (2) desde la cabecera
      expect(find.byKey(const Key('pending_spam_tab_button')), findsOneWidget);
      expect(find.text('Spam (2)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pending_spam_tab_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('spam_retention_banner')), findsOneWidget);
      expect(find.byKey(const Key('spam_card_spam_1')), findsOneWidget);
      expect(find.byKey(const Key('spam_card_spam_2')), findsOneWidget);

      // 1. Reconfirmar spam_1 -> desaparece de la lista Spam
      await tester.tap(find.byKey(const Key('confirm_spam_spam_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('spam_card_spam_1')), findsNothing);
      expect(notifier.spamItems.length, equals(1));

      // 2. Rescatar spam_2 ("A Pendientes") -> vuelve a Pendientes y cambia de vista
      await tester.tap(find.byKey(const Key('restore_spam_spam_2')));
      await tester.pumpAndSettle();
      expect(notifier.spamItems, isEmpty);
      expect(notifier.items.length, equals(1));
      expect(find.text('El Corral'), findsOneWidget);
    },
  );
}
