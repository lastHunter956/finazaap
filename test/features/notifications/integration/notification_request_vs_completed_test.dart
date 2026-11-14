import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/notification_parser.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';

class _InMemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}

class _SyntheticNotificationSource implements NotificationSourcePort {
  final StreamController<NotificationEvent> _controller =
      StreamController<NotificationEvent>.broadcast();
  bool _listening = false;

  @override
  Stream<NotificationEvent> get notificationStream => _controller.stream;

  @override
  Future<NotificationSourceStatus> checkStatus() async =>
      NotificationSourceStatus(
        isListening: _listening,
        permissionStatus: NotificationPermissionStatus.granted,
      );

  @override
  Future<bool> startListening() async {
    _listening = true;
    return true;
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  void emit(NotificationEvent event) {
    if (_listening) {
      _controller.add(event);
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Fixture sintético basado en el caso real reportado:
/// pago de tarjeta desde Nu vía ATH/Banco de Occidente con notificación
/// previa de solicitud ("Tienes un pago...") y notificación de aprobación
/// ("Nu: Pago aprobado...") a las 09:20.
class _NotificationRequestVsApprovedFixture {
  static const String nuPackage = 'com.nu.production';
  static const String occidentePackage = 'com.bancodeoccidente.movil';
  static const String walletOrBrowserHelperPackage = 'com.bancolombia.personas';

  static final DateTime eventTime = DateTime(2026, 11, 14, 9, 20);

  static final List<AccountItem> syntheticAccounts = [
    AccountItem(
      title: 'Nu',
      balance: '1000000',
      icon: Icons.account_balance_wallet,
      iconColor: Colors.purple,
      subtitle: 'Cuenta Nu *1111',
    ),
    AccountItem(
      title: 'Banco de Occidente',
      balance: '5000000',
      icon: Icons.credit_card,
      iconColor: Colors.blue,
      subtitle: 'TC *4444',
      creditLimit: '5000000',
    ),
  ];

  static NotificationEvent approvedNuPayment({
    String id = 'syn_nu_approved_0920',
    DateTime? timestamp,
    String merchantSuffix = 'Banco de Occidente S.A. (ATH)',
  }) =>
      NotificationEvent(
        id: id,
        packageName: nuPackage,
        title: 'Nu: Pago aprobado',
        body:
            'Pago aprobado por \$225.881,00. Pagaste en $merchantSuffix con tu cuenta',
        timestamp: timestamp ?? eventTime,
      );

  static NotificationEvent pendingPaymentRequest({
    String id = 'syn_occidente_request_0920',
    DateTime? timestamp,
    String packageName = occidentePackage,
  }) =>
      NotificationEvent(
        id: id,
        packageName: packageName,
        title: 'Pago pendiente',
        body:
            'Tienes un pago por \$225.881,00 de Banco de Occidente S.A. (ATH). Completa tu pago de forma fácil y segura en la app',
        timestamp: timestamp ?? eventTime,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_notif_repro_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<
      ({
        NotificationPipelineService pipeline,
        _SyntheticNotificationSource source,
        MockTransactionExecutionAdapter executionPort,
        Box<dynamic> dedupBox,
        Box<dynamic> pendingBox,
        Box<dynamic> executedBox,
        Box<dynamic> patternsBox,
      })> createIsolatedPipeline(String suffix) async {
    final encodedAccounts = _NotificationRequestVsApprovedFixture
        .syntheticAccounts
        .map((a) => jsonEncode(a.toJson()))
        .toList();

    SharedPreferences.setMockInitialValues({
      'accounts': encodedAccounts,
      NotificationPipelineService.captureEnabledPrefsKey: true,
      NotificationPipelineService.autoAcceptFuturePrefsKey: false,
    });

    final encryption = NotificationBoxEncryption(
      keyStore: _InMemorySecureKeyStore(),
    );
    final whitelist = BankWhitelistService();
    await whitelist.setBankEnabled(
      _NotificationRequestVsApprovedFixture.nuPackage,
      true,
    );
    await whitelist.setBankEnabled(
      _NotificationRequestVsApprovedFixture.occidentePackage,
      true,
    );
    await whitelist.setBankEnabled(
      _NotificationRequestVsApprovedFixture.walletOrBrowserHelperPackage,
      true,
    );

    final source = _SyntheticNotificationSource();
    final executionPort = MockTransactionExecutionAdapter();
    final dedupBox = await Hive.openBox<dynamic>('repro_dedup_$suffix');
    final pendingBox = await Hive.openBox<dynamic>('repro_pending_$suffix');
    final executedBox = await Hive.openBox<dynamic>('repro_executed_$suffix');
    final patternsBox = await Hive.openBox<dynamic>('repro_patterns_$suffix');

    final pipeline = NotificationPipelineService(
      boxEncryption: encryption,
      whitelistService: whitelist,
      source: source,
      executionPort: executionPort,
      dedupBox: dedupBox,
      pendingBox: pendingBox,
      executedBox: executedBox,
      patternsBox: patternsBox,
    );
    await pipeline.initialize();
    await pipeline.setCaptureEnabled(true);

    return (
      pipeline: pipeline,
      source: source,
      executionPort: executionPort,
      dedupBox: dedupBox,
      pendingBox: pendingBox,
      executedBox: executedBox,
      patternsBox: patternsBox,
    );
  }

  test(
    'Caso 1: solicitud + aprobación por \$225.881 en el mismo minuto no deben producir 2 movimientos contabilizables',
    () async {
      final env = await createIsolatedPipeline('case1');
      addTearDown(() async {
        await env.source.dispose();
        await env.dedupBox.close();
        await env.pendingBox.close();
        await env.executedBox.close();
        await env.patternsBox.close();
      });

      env.source.emit(
        _NotificationRequestVsApprovedFixture.approvedNuPayment(),
      );
      env.source.emit(
        _NotificationRequestVsApprovedFixture.pendingPaymentRequest(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await env.pipeline.flushPendingProcessing();

      final items = env.pipeline.pendingNotifier.items;
      expect(
        items.length,
        1,
        reason:
            'La solicitud previa ("Tienes un pago... Completa tu pago") no debe duplicar la operación aprobada como un segundo movimiento.',
      );
      expect(items.single.rawText, contains('Pago aprobado'));
      expect(items.single.requiresReview, isTrue);
      expect(items.single.autoProcessable, isFalse);
      expect(items.single.destinationAccount, isNull);
      expect(env.executionPort.executionCount, 0);
    },
  );

  test(
    'Caso 2: una solicitud sola no debe clasificarse ni encolarse como pago completado',
    () async {
      final parser = NotificationParser();
      final requestEvent =
          _NotificationRequestVsApprovedFixture.pendingPaymentRequest();

      final parseResult = parser.parse(requestEvent);

      // Si llega al clasificador, tampoco debe quedar como gasto completado.
      if (parseResult is ParsedTransaction) {
        final classifier = TransactionClassifier(
          accountsLoader: () async =>
              _NotificationRequestVsApprovedFixture.syntheticAccounts,
        );
        final classification = await classifier.classify(
          parseResult: parseResult,
          rawText: '${requestEvent.title}. ${requestEvent.body}',
          userAccounts: _NotificationRequestVsApprovedFixture.syntheticAccounts,
        );

        expect(
          classification.createTransaction,
          isFalse,
          reason:
              'Una solicitud pendiente ("Tienes un pago... Completa tu pago") no es un pago consumado y no debe ser contabilizable.',
        );
      } else {
        expect(parseResult, isA<UnparseableNotification>());
      }
    },
  );

  test(
    'Caso 3: dos pagos reales distintos de igual importe en el mismo minuto deben seguir siendo posibles',
    () async {
      final env = await createIsolatedPipeline('case3');
      addTearDown(() async {
        await env.source.dispose();
        await env.dedupBox.close();
        await env.pendingBox.close();
        await env.executedBox.close();
        await env.patternsBox.close();
      });

      env.source.emit(
        _NotificationRequestVsApprovedFixture.approvedNuPayment(
          id: 'syn_real_1',
          merchantSuffix: 'Comercio A',
        ),
      );
      env.source.emit(
        _NotificationRequestVsApprovedFixture.approvedNuPayment(
          id: 'syn_real_2',
          merchantSuffix: 'Comercio B',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await env.pipeline.flushPendingProcessing();

      expect(
        env.pipeline.pendingNotifier.items.length,
        2,
        reason:
            'Dos pagos reales aprobados de igual importe y mismo minuto no deben fusionarse.',
      );
    },
  );

  test(
    'Caso 4: sin evidencia suficiente de pago a tarjeta propia, no debe inventar transferencia-propia auto-aprobada',
    () async {
      final parser = NotificationParser();
      final approvedEvent =
          _NotificationRequestVsApprovedFixture.approvedNuPayment();
      final parseResult = parser.parse(approvedEvent);
      final classifier = TransactionClassifier(
        accountsLoader: () async =>
            _NotificationRequestVsApprovedFixture.syntheticAccounts,
      );

      final classification = await classifier.classify(
        parseResult: parseResult,
        rawText: '${approvedEvent.title}. ${approvedEvent.body}',
        userAccounts: _NotificationRequestVsApprovedFixture.syntheticAccounts,
        packageName: approvedEvent.packageName,
      );

      // Si se propone transferencia-propia solo por mencionar el nombre del banco,
      // debe exigir confirmación (requiresReview == true), no auto-confirmarla.
      expect(classification.requiresReview, isTrue);
      expect(classification.createTransaction, isFalse);
      if (classification.classification == 'transferencia-propia') {
        expect(
          classification.requiresReview,
          isTrue,
          reason:
              'Mencionar "Banco de Occidente S.A. (ATH)" no prueba sin ambigüedad que el destino sea la tarjeta propia; requiere confirmación.',
        );
      } else {
        // Si queda como gasto / pago sin destino inferido, tampoco debe inventar destinationAccount.
        expect(classification.destinationAccount, isNull);
      }
    },
  );

  test(
    'Caso 5: varios productos del mismo banco sin desambiguación exigen revisión y no usan fallback',
    () async {
      final multiNuAccounts = [
        AccountItem(
          title: 'Nu Ahorros',
          balance: '1000000',
          icon: Icons.account_balance_wallet,
          iconColor: Colors.purple,
          subtitle: 'Cuenta Nu *1111',
        ),
        AccountItem(
          title: 'Nu Tarjeta de Crédito',
          balance: '3000000',
          icon: Icons.credit_card,
          iconColor: Colors.purple,
          subtitle: 'TC Nu *2222',
          creditLimit: '3000000',
        ),
      ];
      final parser = NotificationParser();
      final event = NotificationEvent(
        id: 'syn_nu_multi_product',
        packageName: _NotificationRequestVsApprovedFixture.nuPackage,
        title: 'Nu: Pago aprobado',
        body: 'Pago aprobado por \$50.000,00 en Comercio Local',
        timestamp: _NotificationRequestVsApprovedFixture.eventTime,
      );
      final parseResult = parser.parse(event);
      final classifier = TransactionClassifier(
        accountsLoader: () async => multiNuAccounts,
      );

      final classification = await classifier.classify(
        parseResult: parseResult,
        rawText: '${event.title}. ${event.body}',
        userAccounts: multiNuAccounts,
        packageName: event.packageName,
      );

      expect(classification.accountName, isNull);
      expect(classification.requiresReview, isTrue);
      expect(classification.createTransaction, isFalse);
    },
  );

  test(
    'Caso 6: pago aprobado real con texto adicional de recordatorio de próximo pago se conserva',
    () async {
      final parser = NotificationParser();
      final event = NotificationEvent(
        id: 'syn_approved_with_reminder',
        packageName: _NotificationRequestVsApprovedFixture.nuPackage,
        title: 'Nu: Pago aprobado',
        body:
            'Pago aprobado por \$225.881,00. Pagaste en Comercio X. Recuerda tu próximo pago antes del 30/11',
        timestamp: _NotificationRequestVsApprovedFixture.eventTime,
      );

      final parseResult = parser.parse(event);
      expect(parseResult, isA<ParsedTransaction>());
      final parsed = parseResult as ParsedTransaction;
      expect(parsed.tipo, equals('gasto'));
      expect(parsed.monto, closeTo(225881.0, 0.01));
    },
  );

  test(
    'Caso 7: pago aprobado con cuenta/destino ambiguos llega a Pendientes como propuesta corregible sin alterar saldos ni auto-ejecutarse',
    () async {
      final env = await createIsolatedPipeline('case7');
      addTearDown(() async {
        await env.source.dispose();
        await env.dedupBox.close();
        await env.pendingBox.close();
        await env.executedBox.close();
        await env.patternsBox.close();
      });

      await env.pipeline.setAutoAcceptFutureEnabled(true);

      env.source.emit(
        _NotificationRequestVsApprovedFixture.approvedNuPayment(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await env.pipeline.flushPendingProcessing();

      final items = env.pipeline.pendingNotifier.items;
      expect(items.length, 1);
      final item = items.single;
      expect(item.rawText, contains('Pago aprobado'));
      expect(item.requiresReview, isTrue);
      expect(item.autoProcessable, isFalse);
      expect(item.destinationAccount, isNull);
      expect(env.executionPort.executionCount, 0);
    },
  );
}
