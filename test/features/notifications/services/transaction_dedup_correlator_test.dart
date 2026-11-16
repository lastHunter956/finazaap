import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/features/notifications/domain/models/dedup_models.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/features/notifications/services/transaction_dedup_correlator.dart';

class _MemKeyStore implements SecureKeyStore {
  final Map<String, String> _map = {};
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
  @override
  Future<void> delete(String key) async => _map.remove(key);
}

class _FakeExecPort implements TransactionExecutionPort {
  @override
  Future<TransactionExecutionResult> execute(
          TransactionExecutionRequest request) async =>
      const TransactionExecutionResult.success(transactionId: 'tx_dedup');

  @override
  Future<bool> executeTransaction({
    required String type,
    required double amount,
    required String accountName,
    String? destinationAccount,
    String? detail,
    DateTime? date,
  }) async =>
      true;
}

class _FakeSource implements NotificationSourcePort {
  final StreamController<NotificationEvent> _ctrl =
      StreamController<NotificationEvent>.broadcast();

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

  void emit(NotificationEvent event) => _ctrl.add(event);

  Future<void> dispose() => _ctrl.close();
}

PendingTransactionItem _buildItem({
  required String id,
  required String comercio,
  required double monto,
  required DateTime fecha,
  String classification = 'gasto',
  String? accountName = 'Bancolombia Ahorros',
  String channel = 'app',
  String? referenceId,
  String? rawText,
}) {
  return PendingTransactionItem(
    id: id,
    rawText: rawText ?? 'Compra por \$$monto en $comercio',
    comercio: comercio,
    monto: monto,
    fecha: fecha,
    classification: classification,
    moneoType: classification == 'ingreso' ? 'Income' : 'Expenses',
    category: 'Otros',
    accountName: accountName,
    confidence: 0.90,
    requiresReview: false,
    autoProcessable: true,
    decisionSource: 'deterministic_rules',
    createdAt: fecha,
    channel: channel,
    referenceId: referenceId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('dedup_correlator_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('TransactionDedupCorrelator - Normalización, Blocking y Casos Límite', () {
    test('Genera blockingKey (YYYY-MM-DD|monto|merchantHash) y extrae referencia UTR/Ref',
        () {
      final correlator = TransactionDedupCorrelator();
      final item = _buildItem(
        id: '1',
        comercio: 'Éxito Laureles 034',
        monto: 45900.40,
        fecha: DateTime(2026, 11, 15, 14, 30),
        rawText: 'Compra aprobada en Éxito Laureles Ref: AB123456',
      );

      final norm = correlator.normalizeItem(item, packageName: 'com.bancolombia');
      expect(norm.dateKey, equals('2026-11-15'));
      expect(norm.roundedAmount, equals(45900));
      expect(norm.normalizedMerchant, equals('exito laureles'));
      expect(norm.referenceId, equals('AB123456'));
      expect(norm.type, equals('debito'));
      expect(norm.blockingKey, startsWith('2026-11-15|45900|'));
    });

    test('Caso límite 1: mismo monto pero comercios distintos = NO duplicado',
        () async {
      final correlator = TransactionDedupCorrelator();
      final t = DateTime(2026, 11, 15, 10, 0);

      final existing = _buildItem(
        id: 'p1',
        comercio: 'Farmacia Cruz Verde',
        monto: 35000,
        fecha: t,
      );
      final incoming = _buildItem(
        id: 'p2',
        comercio: 'Restaurante El Corral',
        monto: 35000,
        fecha: t.add(const Duration(minutes: 5)),
      );

      final res = await correlator.correlate(
        candidate: incoming,
        existingPending: [existing],
      );
      expect(res.decision, equals(CorrelationDecisionType.unique));
      expect(res.shouldMergeIntoExisting, isFalse);
    });

    test('Caso límite 2: compra recurrente mensual (misma fecha cada mes) = NO duplicado',
        () async {
      final correlator = TransactionDedupCorrelator();
      final existing = _buildItem(
        id: 'm1',
        comercio: 'Netflix Colombia',
        monto: 39900,
        fecha: DateTime(2026, 10, 15, 8, 0),
      );
      final incoming = _buildItem(
        id: 'm2',
        comercio: 'Netflix Colombia',
        monto: 39900,
        fecha: DateTime(2026, 11, 15, 8, 0),
      );

      final res = await correlator.correlate(
        candidate: incoming,
        existingPending: [existing],
      );
      expect(res.decision, equals(CorrelationDecisionType.unique));
    });

    test(
        'Caso límite 3: misma ventana corta (48h) + mismo comercio + mismo monto = candidato a duplicado',
        () async {
      final correlator = TransactionDedupCorrelator();
      final t = DateTime(2026, 11, 15, 18, 0);
      final existing = _buildItem(
        id: 'd1',
        comercio: 'Supermercado D1',
        monto: 62500,
        fecha: t,
        channel: 'app',
      );
      final incoming = _buildItem(
        id: 'd2',
        comercio: 'SUPERMERCADO D1 042',
        monto: 62500,
        fecha: t.add(const Duration(hours: 6)),
        channel: 'sms',
      );

      final res = await correlator.correlate(
        candidate: incoming,
        existingPending: [existing],
      );
      expect(
        res.decision,
        equals(CorrelationDecisionType.probabilisticDuplicate),
      );
      expect(res.matchedPendingItemId, equals('d1'));
      expect(res.similarityScore, greaterThanOrEqualTo(0.90));
    });

    test('Matching determinista por referenceId (UTR/Ref) detecta duplicado exacto',
        () async {
      final correlator = TransactionDedupCorrelator();
      final t = DateTime(2026, 11, 15, 12, 0);
      final existing = _buildItem(
        id: 'r1',
        comercio: 'Éxito',
        monto: 80000,
        fecha: t,
        rawText: 'Compra en Exito Ref: UTR998877',
      );
      final incoming = _buildItem(
        id: 'r2',
        comercio: 'Exito',
        monto: 80000,
        fecha: t.add(const Duration(minutes: 10)),
        channel: 'correo',
        rawText: 'Correo: cargo en Exito Ref: UTR998877',
      );

      final res = await correlator.correlate(
        candidate: incoming,
        existingPending: [existing],
      );
      expect(res.decision, equals(CorrelationDecisionType.exactDuplicate));
      expect(res.matchedPendingItemId, equals('r1'));
    });

    test(
        'Caso límite 4: débito en cuenta A + crédito en cuenta B mismo monto/ventana corta = 1 transferencia',
        () async {
      final correlator = TransactionDedupCorrelator();
      final t = DateTime(2026, 11, 15, 15, 0);

      final debitA = _buildItem(
        id: 'tx_a',
        comercio: 'Transferencia enviada',
        monto: 250000,
        fecha: t,
        classification: 'gasto',
        accountName: 'Bancolombia Ahorros',
      );
      final creditB = _buildItem(
        id: 'tx_b',
        comercio: 'Transferencia recibida',
        monto: 250000,
        fecha: t.add(const Duration(minutes: 2)),
        classification: 'ingreso',
        accountName: 'Nequi',
      );

      final res = await correlator.correlate(
        candidate: creditB,
        existingPending: [debitA],
      );
      expect(
        res.decision,
        equals(CorrelationDecisionType.internalTransferPair),
      );
      expect(res.proposedSourceAccount, equals('Bancolombia Ahorros'));
      expect(res.proposedDestinationAccount, equals('Nequi'));

      final merged = correlator.mergeIntoPendingItem(
        existing: debitA,
        incoming: creditB,
        correlation: res,
      );
      expect(merged.classification, equals('transferencia-propia'));
      expect(merged.moneoType, equals('Transfer'));
      expect(merged.accountName, equals('Bancolombia Ahorros'));
      expect(merged.destinationAccount, equals('Nequi'));
      expect(merged.groupedCount, equals(2));
    });
  });

  group('Aprendizaje del usuario ("estos N son uno" / "separar") y Pipeline',
      () {
    test('mergePendingItems agrupa N ítems, guarda regla reutilizable y splitMergedItem los separa',
        () async {
      final pendingBox = await Hive.openBox<dynamic>(
          'pending_merge_test_${DateTime.now().microsecondsSinceEpoch}');
      final rulesBox = await Hive.openBox<dynamic>(
          'rules_merge_test_${DateTime.now().microsecondsSinceEpoch}');
      addTearDown(() async {
        await pendingBox.close();
        await rulesBox.close();
      });

      final correlator = TransactionDedupCorrelator(rulesBox: rulesBox);
      final notifier = PendingTransactionsNotifier(
        box: pendingBox,
        executionPort: _FakeExecPort(),
        dedupCorrelator: correlator,
      );
      await notifier.initialize();

      final t = DateTime(2026, 11, 15, 11, 0);
      await notifier.addPendingItems([
        _buildItem(
          id: 'i1',
          comercio: 'Rappi Prime',
          monto: 24900,
          fecha: t,
          channel: 'app',
        ),
        _buildItem(
          id: 'i2',
          comercio: 'Rappi',
          monto: 24900,
          fecha: t.add(const Duration(minutes: 3)),
          channel: 'sms',
        ),
      ]);
      expect(notifier.count, equals(2));

      final merged = await notifier.mergePendingItems(['i1', 'i2']);
      expect(merged, isNotNull);
      expect(notifier.count, equals(1));
      expect(merged!.isGrouped, isTrue);
      expect(merged.groupedCount, equals(2));

      final rule = await correlator.findDedupRule('Rappi Prime');
      expect(rule, isNotNull);
      expect(rule!.channels, containsAll(['app', 'sms']));

      final splitOk = await notifier.splitMergedItem(merged.id);
      expect(splitOk, isTrue);
      expect(notifier.count, equals(2));
    });

    test(
        'Pipeline propone 1 sola transferencia ante débito en Bancolombia + crédito en Nequi',
        () async {
      SharedPreferences.setMockInitialValues({
        'accounts': [
          jsonEncode(AccountItem(
            icon: Icons.account_balance,
            title: 'Bancolombia Ahorros',
            subtitle: 'Ahorros *1111',
            balance: '1000000',
            iconColor: Colors.yellow,
          ).toJson()),
          jsonEncode(AccountItem(
            icon: Icons.account_balance_wallet,
            title: 'Nequi',
            subtitle: 'Nequi *2222',
            balance: '500000',
            iconColor: Colors.purple,
          ).toJson()),
        ],
      });

      final enc = NotificationBoxEncryption(keyStore: _MemKeyStore());
      final dedupBox = await enc.openEncryptedBox('pipe_trf_dedup');
      final pendingBox = await enc.openEncryptedBox('pipe_trf_pending');
      final executedBox = await enc.openEncryptedBox('pipe_trf_exec');
      final patternsBox = await enc.openEncryptedBox('pipe_trf_pat');
      final rulesBox = await enc.openEncryptedBox('pipe_trf_rules');
      final source = _FakeSource();

      final pipeline = NotificationPipelineService(
        boxEncryption: enc,
        whitelistService: BankWhitelistService(),
        source: source,
        executionPort: _FakeExecPort(),
        dedupBox: dedupBox,
        pendingBox: pendingBox,
        executedBox: executedBox,
        patternsBox: patternsBox,
        dedupRulesBox: rulesBox,
      );

      addTearDown(() async {
        await pipeline.dispose();
        await source.dispose();
        await dedupBox.close();
        await pendingBox.close();
        await executedBox.close();
        await patternsBox.close();
        await rulesBox.close();
      });

      await pipeline.initialize();
      await pipeline.setCaptureEnabled(true);

      final now = DateTime(2026, 11, 16, 10, 0);
      source.emit(NotificationEvent(
        id: 'ev_debit_bancolombia',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Pagaste \$150.000 desde Bancolombia Ahorros a Nequi',
        timestamp: now,
      ));
      source.emit(NotificationEvent(
        id: 'ev_credit_nequi',
        packageName: 'com.nequi.MobileApp',
        title: 'Nequi',
        body: 'Recibiste \$150.000 en tu cuenta Nequi',
        timestamp: now.add(const Duration(seconds: 15)),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pipeline.flushPendingProcessing();

      expect(pipeline.pendingNotifier.items.length, equals(1));
      final proposed = pipeline.pendingNotifier.items.single;
      expect(proposed.classification, equals('transferencia-propia'));
      expect(proposed.accountName, equals('Bancolombia Ahorros'));
      expect(proposed.destinationAccount, equals('Nequi'));
    });
  });
}
