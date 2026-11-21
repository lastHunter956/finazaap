import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/domain/models/spam_models.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/gemma_classifier_adapter.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/local_gemma_coordinator.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/features/notifications/services/spam_patterns_service.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';
import 'package:finazaap/services/ai_financial_tools.dart';
import 'package:finazaap/services/device_capability_service.dart';

class _FakeGemmaClient implements GemmaInferenceClient {
  bool loaded;
  String? Function(String prompt)? responder;
  int callCount = 0;
  final List<String> prompts = [];

  _FakeGemmaClient({this.loaded = true, this.responder});

  @override
  Future<bool> isModelLoaded() async => loaded;

  @override
  Future<String?> generateResponse(String prompt) async {
    callCount++;
    prompts.add(prompt);
    return responder?.call(prompt);
  }
}

class _FakeNotificationSource implements NotificationSourcePort {
  final StreamController<NotificationEvent> _ctrl =
      StreamController<NotificationEvent>.broadcast();

  void emit(NotificationEvent event) => _ctrl.add(event);

  @override
  Stream<NotificationEvent> get notificationStream => _ctrl.stream;

  @override
  Future<NotificationSourceStatus> checkStatus() async =>
      const NotificationSourceStatus(
        isListening: true,
        permissionStatus: NotificationPermissionStatus.granted,
      );

  @override
  Future<bool> startListening() async => true;

  @override
  Future<void> stopListening() async {}

  Future<void> dispose() => _ctrl.close();
}

void main() {
  late Directory tempDir;
  int boxCounter = 0;

  Future<Box<dynamic>> openTempBox(String prefix) {
    boxCounter++;
    return Hive.openBox<dynamic>(
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$boxCounter',
    );
  }

  final sampleAccounts = <AccountItem>[
    AccountItem(
      id: 'acc-nu',
      title: 'Nu',
      subtitle: 'Ahorros *1111',
      balance: '1000000',
      icon: Icons.account_balance,
      iconColor: Colors.purple,
    ),
    AccountItem(
      id: 'acc-rappi',
      title: 'Rappi',
      subtitle: 'RappiCuenta *2222',
      balance: '200000',
      icon: Icons.account_balance_wallet,
      iconColor: Colors.orange,
    ),
    AccountItem(
      id: 'acc-rappicard',
      title: 'RappiCard',
      subtitle: 'Tarjeta *3333',
      balance: '0',
      icon: Icons.credit_card,
      iconColor: Colors.deepOrange,
      creditLimit: '5000000',
    ),
    AccountItem(
      id: 'acc-nequi',
      title: 'Nequi',
      subtitle: 'Celular *4444',
      balance: '300000',
      icon: Icons.phone_android,
      iconColor: Colors.pink,
    ),
  ];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('spam_ai_batch_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Spam Patterns + Cuarentena 5 días + Atajo 0-IA', () {
    test(
      'descartar promo de Rappi aprende patrón -> siguiente promo similar va a Spam con 0 llamadas a la IA',
      () async {
        final patternsBox = await openTempBox('patterns');
        final spamPatternsBox = await openTempBox('dismissed');
        final pendingBox = await openTempBox('pending');
        final spamItemsBox = await openTempBox('spam_items');

        final patternsService = LearnedPatternsService(box: patternsBox);
        final spamPatternsService = SpamPatternsService(box: spamPatternsBox);
        final fakeClient = _FakeGemmaClient(
          responder: (_) =>
              '{"is_transaction": true, "classification": "gasto", "category": "Comida", "confidence": 0.9}',
        );
        final classifier = TransactionClassifier(
          patternsService: patternsService,
          spamPatternsService: spamPatternsService,
          gemmaAdapter: GemmaClassifierAdapter(client: fakeClient),
          accountsLoader: () async => sampleAccounts,
          categoriesLoader: () async => (
            expenses: ['Comida', 'Transporte', 'Mercado'],
            income: ['Salario'],
          ),
          enableAiEnrichment: true,
        );
        final notifier = PendingTransactionsNotifier(
          box: pendingBox,
          spamBox: spamItemsBox,
          learnedPatternsService: patternsService,
          spamPatternsService: spamPatternsService,
          executionPort: MockTransactionExecutionAdapter(),
        );

        // 1. Usuario descarta una promo que había entrado a pendientes
        await notifier.addPendingItem(
          PendingTransactionItem(
            id: 'rappi_promo_1',
            rawText: 'Rappi. ¡Tienes \$15.000 de descuento en tu compra de hoy!',
            comercio: 'Rappi',
            monto: 15000,
            fecha: DateTime(2026, 11, 21, 12, 0),
            classification: 'gasto',
            moneoType: 'Expenses',
            category: 'Otros',
            confidence: 0.70,
            requiresReview: true,
            autoProcessable: false,
            decisionSource: 'deterministic_rules',
            createdAt: DateTime(2026, 11, 21, 12, 0),
            packageName: 'com.grability.rappi',
            channelId: 'rappi_promos_marketing',
          ),
        );

        await notifier.discardItem('rappi_promo_1');
        expect(notifier.items, isEmpty);
        expect(notifier.spamItems.length, equals(1));

        // 2. Llega otra promo similar de Rappi con otro monto -> atajo 0-IA
        final parsed2 = ParsedTransaction(
          tipo: 'gasto',
          monto: 25000,
          fecha: DateTime(2026, 11, 21, 13, 0),
          confidence: 0.45,
          requiresReview: true,
          autoProcessable: false,
          isPromoSignal: true,
        );
        final res2 = await classifier.classify(
          parseResult: parsed2,
          rawText: 'Rappi. ¡Tienes \$25.000 de descuento en tu compra de hoy!',
          packageName: 'com.grability.rappi',
          channelId: 'rappi_promos_marketing',
        );

        expect(res2.isSpam, isTrue);
        expect(res2.decisionSource, equals('learned_spam'));
        expect(
          fakeClient.callCount,
          equals(0),
          reason: 'No debe invocar a la IA cuando el patrón de spam ya está marcado',
        );

        // 3. Si el usuario pulsa "No es spam" (restoreFromSpam), se desactiva la regla
        final restored = await notifier.restoreFromSpam('rappi_promo_1');
        expect(restored, isNotNull);
        expect(notifier.spamItems, isEmpty);
        expect(notifier.items.length, equals(1));

        final afterRescue = await spamPatternsService.matchSpam(
          packageName: 'com.grability.rappi',
          rawText: 'Rappi. ¡Tienes \$25.000 de descuento en tu compra de hoy!',
          channelId: 'rappi_promos_marketing',
        );
        expect(
          afterRescue,
          isNull,
          reason: 'Al marcar No es spam debe desactivar la regla que la atrapó',
        );
      },
    );

    test('auto-poda elimina ítems de Spam con > 5 días y conserva los vigentes', () async {
      final pendingBox = await openTempBox('pending_prune');
      final spamBox = await openTempBox('spam_prune');
      final notifier = PendingTransactionsNotifier(
        box: pendingBox,
        spamBox: spamBox,
        executionPort: MockTransactionExecutionAdapter(),
      );

      final now = DateTime(2026, 11, 21, 12, 0);
      final oldDate = now.subtract(const Duration(days: 6));
      final recentDate = now.subtract(const Duration(days: 3));

      PendingTransactionItem makeItem(String id, DateTime dt) =>
          PendingTransactionItem(
            id: id,
            rawText: 'Promo $id por \$10.000',
            monto: 10000,
            fecha: dt,
            classification: 'spam',
            confidence: 0.9,
            requiresReview: false,
            autoProcessable: false,
            decisionSource: 'promo_filter',
            createdAt: dt,
          );

      await spamBox.put(
        'spam_old',
        SpamNotificationItem(
          id: 'spam_old',
          item: makeItem('spam_old', oldDate),
          spamReason: 'Promo vieja',
          spamSource: 'promo_filter',
          detectedAt: oldDate,
        ).toJson(),
      );
      await spamBox.put(
        'spam_recent',
        SpamNotificationItem(
          id: 'spam_recent',
          item: makeItem('spam_recent', recentDate),
          spamReason: 'Promo reciente',
          spamSource: 'promo_filter',
          detectedAt: recentDate,
        ).toJson(),
      );

      final pruned = await notifier.pruneExpiredSpam(now: now);
      expect(pruned, equals(1));
      expect(spamBox.containsKey('spam_old'), isFalse);
      expect(spamBox.containsKey('spam_recent'), isTrue);
    });
  });

  group('Presupuesto fijo de tokens (2B), Guardrails Post-IA y RappiCard vs Rappi', () {
    test(
      'con 200 patrones guardados el prompt para Gemma 2B se mantiene <= 550 tokens',
      () async {
        final patternsBox = await openTempBox('patterns_200');
        final spamPatternsBox = await openTempBox('spam_200');
        final patternsService = LearnedPatternsService(box: patternsBox);
        final spamService = SpamPatternsService(box: spamPatternsBox);

        for (var i = 0; i < 200; i++) {
          await patternsService.recordConfirmation(
            merchant: 'Comercio Recurrente Numero $i Sucursal',
            category: i % 2 == 0 ? 'Comida' : 'Transporte',
            accountName: i % 2 == 0 ? 'RappiCard' : 'Nu',
            packageName: 'com.grability.rappi',
          );
        }
        for (var i = 0; i < 40; i++) {
          await spamService.recordDismissal(
            packageName: 'com.grability.rappi',
            rawText: 'Oferta especial numero $i con \$10.000 de descuento',
            channelId: 'promos',
          );
        }

        final fakeClient = _FakeGemmaClient(
          responder: (_) =>
              '{"is_transaction":true,"classification":"gasto","amount":38000,"description":"Pedido El Corral","category":"Comida","account_name":"RappiCard","confidence":0.92,"strategic_note":"Compra con RappiCard"}',
        );

        final classifier = TransactionClassifier(
          patternsService: patternsService,
          spamPatternsService: spamService,
          gemmaAdapter: GemmaClassifierAdapter(client: fakeClient),
          accountsLoader: () async => sampleAccounts,
          categoriesLoader: () async => (
            expenses: ['Comida', 'Transporte', 'Mercado', 'Servicios', 'Salud'],
            income: ['Salario', 'Extras'],
          ),
          enableAiEnrichment: true,
        );

        final parsed = ParsedTransaction(
          tipo: 'gasto',
          monto: 38000,
          candidateAmounts: const [38000],
          comercio: 'El Corral',
          fecha: DateTime(2026, 11, 21, 13, 0),
          confidence: 0.85,
          requiresReview: false,
          autoProcessable: true,
        );

        final res = await classifier.classify(
          parseResult: parsed,
          rawText: 'Rappi. Compra aprobada por \$38.000 en El Corral con tu RappiCard',
          packageName: 'com.grability.rappi',
          appName: 'Rappi / RappiPay',
          channelId: 'rappicard_tx',
        );

        expect(fakeClient.callCount, equals(1));
        final estimatedTokens =
            AiTokenBudget.estimateTokens(fakeClient.prompts.first);
        expect(
          estimatedTokens,
          lessThanOrEqualTo(GemmaClassifierAdapter.localMaxInputTokens + 15),
          reason: 'El prompt 2B debe mantenerse acotado en O(1) incluso con 200 reglas',
        );
        expect(res.accountName, equals('RappiCard'));
        expect(res.category, equals('Comida'));
        expect(res.suggestedDescription, equals('Pedido El Corral'));
        expect(res.suggestedAmount, equals(38000.0));
      },
    );

    test(
      'guardrails Post-IA bloquean monto alucinado y cuenta inventada por la IA',
      () async {
        final patternsBox = await openTempBox('patterns_guard');
        final fakeClient = _FakeGemmaClient(
          responder: (_) =>
              '{"is_transaction":true,"classification":"gasto","amount":999999,"description":"Cafe Quindio","category":"Comida","account_name":"Cuenta Inventada XYZ","confidence":0.95}',
        );
        final classifier = TransactionClassifier(
          patternsService: LearnedPatternsService(box: patternsBox),
          gemmaAdapter: GemmaClassifierAdapter(client: fakeClient),
          accountsLoader: () async => sampleAccounts,
          categoriesLoader: () async => (
            expenses: ['Comida', 'Transporte'],
            income: ['Salario'],
          ),
          enableAiEnrichment: true,
        );

        final parsed = ParsedTransaction(
          tipo: 'desconocido',
          monto: 5800,
          candidateAmounts: const [5800],
          comercio: 'Cafe Quindio',
          fecha: DateTime(2026, 11, 21, 14, 0),
          confidence: 0.60,
          requiresReview: true,
          autoProcessable: false,
        );

        final res = await classifier.classify(
          parseResult: parsed,
          rawText: 'Movimiento en Cafe Quindio por \$5.800',
        );

        expect(
          res.suggestedAmount,
          equals(5800.0),
          reason: 'No debe aceptar monto alucinado 999999 que no existe en el aviso',
        );
        expect(
          res.accountName,
          isNull,
          reason: 'No debe aceptar una cuenta inexistente ni poner NU por defecto',
        );
        expect(res.requiresReview, isTrue);
        expect(res.createTransaction, isFalse);
      },
    );

    test('RappiCard vs RappiCuenta en com.grability.rappi (fallback determinista)', () async {
      final patternsBox = await openTempBox('patterns_rappi');
      final offlineClient = _FakeGemmaClient(loaded: false);
      final classifier = TransactionClassifier(
        patternsService: LearnedPatternsService(box: patternsBox),
        gemmaAdapter: GemmaClassifierAdapter(client: offlineClient),
        accountsLoader: () async => sampleAccounts,
        categoriesLoader: () async => (
          expenses: ['Comida', 'Mercado'],
          income: ['Salario'],
        ),
      );

      final parsedCard = ParsedTransaction(
        tipo: 'gasto',
        monto: 42000,
        comercio: 'Crepes & Waffles',
        fecha: DateTime(2026, 11, 21, 15, 0),
        confidence: 0.90,
        requiresReview: false,
        autoProcessable: true,
      );
      final resCard = await classifier.classify(
        parseResult: parsedCard,
        rawText: 'Compra aprobada por \$42.000 en Crepes & Waffles con tu RappiCard',
        packageName: 'com.grability.rappi',
      );
      expect(resCard.accountName, equals('RappiCard'));

      final resCuenta = await classifier.classify(
        parseResult: parsedCard,
        rawText: 'Pagaste \$42.000 en Crepes & Waffles desde tu RappiCuenta',
        packageName: 'com.grability.rappi',
      );
      expect(resCuenta.accountName, equals('Rappi'));
    });
  });

  group('Ventana cruzada de 5 minutos + Contexto cruzado en Pipeline', () {
    test(
      'acumula eventos en ventana de 5 min y al hacer flush entrega contexto cruzado a la IA',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPipelineService.captureEnabledPrefsKey: true,
        });

        final dedupBox = await openTempBox('pipe_dedup');
        final pendingBox = await openTempBox('pipe_pending');
        final executedBox = await openTempBox('pipe_exec');
        final patternsBox = await openTempBox('pipe_pat');
        final spamBox = await openTempBox('pipe_spam');
        final dismissedBox = await openTempBox('pipe_dis');
        final rulesBox = await openTempBox('pipe_rules');
        final recentBox = await openTempBox('pipe_recent');

        final fakeSource = _FakeNotificationSource();
        final fakeClient = _FakeGemmaClient(
          responder: (prompt) {
            if (prompt.contains('Otros avisos (ventana 5 min)')) {
              return '{"is_transaction":true,"classification":"transferencia-propia","amount":100000,"description":"Transferencia Nu a Nequi","category":"Transferencia","account_name":"Nu","destination_account":"Nequi","confidence":0.94,"strategic_note":"Cruce Nu -> Nequi en ventana 5 min"}';
            }
            return '{"is_transaction":true,"classification":"gasto","amount":100000,"description":"Movimiento","category":"Comida","account_name":"Nu","confidence":0.85}';
          },
        );
        final patternsService = LearnedPatternsService(box: patternsBox);
        final spamPatternsService = SpamPatternsService(box: dismissedBox);
        final classifier = TransactionClassifier(
          patternsService: patternsService,
          spamPatternsService: spamPatternsService,
          gemmaAdapter: GemmaClassifierAdapter(client: fakeClient),
          accountsLoader: () async => sampleAccounts,
          categoriesLoader: () async => (
            expenses: ['Comida', 'Transporte'],
            income: ['Salario'],
          ),
          enableAiEnrichment: true,
        );

        final pipeline = NotificationPipelineService(
          whitelistService: BankWhitelistService(),
          source: fakeSource,
          executionPort: MockTransactionExecutionAdapter(),
          dedupBox: dedupBox,
          pendingBox: pendingBox,
          executedBox: executedBox,
          patternsBox: patternsBox,
          dedupRulesBox: rulesBox,
          recentMovementsBox: recentBox,
          spamBox: spamBox,
          dismissedPatternsBox: dismissedBox,
          spamPatternsService: spamPatternsService,
          classifier: classifier,
          batchWindow: const Duration(minutes: 5),
          enableAiEnrichment: true,
        );
        await pipeline.initialize();

        final t0 = DateTime(2026, 11, 21, 14, 1);
        fakeSource.emit(
          NotificationEvent(
            id: 'nu_out_1',
            packageName: 'com.nu.production',
            title: 'Nu Colombia',
            body: 'Enviaste \$100.000 desde tu cuenta Nu',
            timestamp: t0,
          ),
        );
        fakeSource.emit(
          NotificationEvent(
            id: 'nequi_in_1',
            packageName: 'com.nequi.MobileApp',
            title: '¡Te llegó plata!',
            body: 'Tu cuenta recibió \$100.000',
            timestamp: t0.add(const Duration(seconds: 40)),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        // Aún en el buffer de la ventana de 5 minutos antes del flush
        expect(pipeline.bufferedBatchCount, equals(2));
        expect(pipeline.pendingNotifier.items, isEmpty);

        // Usuario abre la app -> flush inmediato con ambos avisos cruzados
        await pipeline.flushBatchNow();
        expect(pipeline.bufferedBatchCount, equals(0));
        expect(fakeClient.prompts, isNotEmpty);
        expect(
          fakeClient.prompts.first,
          contains('Otros avisos (ventana 5 min)'),
        );
        expect(
          pipeline.pendingNotifier.items.any(
            (item) =>
                item.classification == 'transferencia-propia' &&
                item.accountName == 'Nu' &&
                item.destinationAccount == 'Nequi',
          ),
          isTrue,
        );

        await pipeline.dispose();
        await fakeSource.dispose();
      },
    );
  });

  group('LocalGemmaCoordinator — Protección de RAM anti-OOM', () {
    test('bloquea carga de Gemma local si lowMemory=true o availRAMGB < 1.8', () async {
      var loaderCalls = 0;
      final coordinator = LocalGemmaCoordinator.custom(
        capabilityCheck: () async => const DeviceCapabilityResult(
          freeStorageGB: 10.0,
          totalRAMGB: 6.0,
          availRAMGB: 1.2, // Debajo del umbral seguro 1.8 GB
          lowMemory: false,
          isArm64: true,
        ),
        modelLoader: ({required maxTokens, required preferredBackend}) async {
          loaderCalls++;
          throw UnimplementedError();
        },
      );

      expect(await coordinator.hasEnoughRamForLocalModel(), isFalse);
      final out = await coordinator.runExclusive<String>(
        maxTokens: 1024,
        action: (_) async => 'ok',
      );
      expect(out, isNull);
      expect(loaderCalls, equals(0));
    });
  });

  group('Feedback Loop — packageName, alias y bloqueo de nombres genéricos de banco', () {
    test('confirmItem guarda packageName y alias, e ignora nombres genéricos de banco', () async {
      final pendingBox = await openTempBox('fb_pending');
      final patternsBox = await openTempBox('fb_patterns');
      final patternsService = LearnedPatternsService(box: patternsBox);
      final notifier = PendingTransactionsNotifier(
        box: pendingBox,
        learnedPatternsService: patternsService,
        executionPort: MockTransactionExecutionAdapter(),
      );

      // 1. Comercio real -> debe guardar con packageName
      await notifier.addPendingItem(
        PendingTransactionItem(
          id: 'tx_real_merchant',
          rawText: 'Compra en Juan Valdez por \$12.000',
          comercio: 'Juan Valdez',
          monto: 12000,
          fecha: DateTime(2026, 11, 21, 10, 0),
          classification: 'gasto',
          moneoType: 'Expenses',
          category: 'Comida',
          accountName: 'RappiCard',
          confidence: 0.90,
          requiresReview: false,
          autoProcessable: true,
          decisionSource: 'gemma_fallback',
          createdAt: DateTime(2026, 11, 21, 10, 0),
          packageName: 'com.grability.rappi',
        ),
      );
      expect(await notifier.confirmItem('tx_real_merchant'), isTrue);
      final jv = await patternsService.findPattern('Juan Valdez');
      expect(jv, isNotNull);
      expect(jv!.knownPackages, contains('com.grability.rappi'));

      // 2. Nombre genérico de banco ("Nu Colombia") -> NO debe contaminar learned_patterns
      await notifier.addPendingItem(
        PendingTransactionItem(
          id: 'tx_generic_bank',
          rawText: 'Pago aprobado por \$20.000',
          comercio: 'Nu Colombia',
          monto: 20000,
          fecha: DateTime(2026, 11, 21, 10, 5),
          classification: 'gasto',
          moneoType: 'Expenses',
          category: 'Comida',
          accountName: 'Nu',
          confidence: 0.85,
          requiresReview: false,
          autoProcessable: true,
          decisionSource: 'deterministic_rules',
          createdAt: DateTime(2026, 11, 21, 10, 5),
          packageName: 'com.nu.production',
        ),
      );
      expect(await notifier.confirmItem('tx_generic_bank'), isTrue);
      final nuPat = await patternsService.findPattern('Nu Colombia');
      expect(
        nuPat,
        isNull,
        reason: 'Nunca debe guardar un nombre genérico de banco como clave de comercio',
      );
    });
  });
}
