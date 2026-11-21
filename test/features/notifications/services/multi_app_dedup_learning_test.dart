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
import 'package:finazaap/features/notifications/domain/models/notification_parse_result.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/domain/models/transaction_classification.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/features/notifications/services/transaction_classifier.dart';
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

class _FakeExecutionPort implements TransactionExecutionPort {
  final List<TransactionExecutionRequest> executed = [];

  @override
  Future<TransactionExecutionResult> execute(
    TransactionExecutionRequest request,
  ) async {
    executed.add(request);
    return TransactionExecutionResult.success(
      transactionId: 'tx_${executed.length}',
    );
  }

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

class _FakeNotificationSource implements NotificationSourcePort {
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

class _StubNoteClassifier extends TransactionClassifier {
  final String note;

  _StubNoteClassifier(this.note);

  @override
  Future<TransactionClassification> classify({
    required NotificationParseResult parseResult,
    String? rawText,
    List<AccountItem>? userAccounts,
    String? packageName,
    String? appName,
    String? channelId,
    List<String> crossNotificationSummaries = const [],
    bool bypassSpamPatterns = false,
  }) async {
    return TransactionClassification(
      classification: 'gasto',
      moneoType: 'Expenses',
      category: 'Alimentación',
      accountName: 'Bancolombia Ahorros',
      confidence: 0.92,
      requiresReview: false,
      createTransaction: true,
      decisionSource: 'learned_patterns',
      strategicNote: note,
    );
  }
}

PendingTransactionItem _makePending({
  required String id,
  required double monto,
  required DateTime fecha,
  String? comercio,
  String? merchantKey,
  String classification = 'gasto',
  String? accountName = 'Bancolombia Ahorros',
  String? destinationAccount,
  String channel = 'app',
  String? packageName,
  String? referenceId,
  String? rawText,
}) {
  return PendingTransactionItem(
    id: id,
    rawText: rawText ?? 'Movimiento por \$$monto en ${comercio ?? "Banco"}',
    comercio: comercio,
    merchantKey: merchantKey ?? comercio?.toLowerCase(),
    monto: monto,
    fecha: fecha,
    classification: classification,
    moneoType: classification == 'transferencia-propia'
        ? 'Transfer'
        : classification == 'ingreso'
            ? 'Income'
            : 'Expenses',
    category: 'Transferencia',
    accountName: accountName,
    destinationAccount: destinationAccount,
    confidence: 0.90,
    requiresReview: false,
    autoProcessable: true,
    decisionSource: 'deterministic_rules',
    createdAt: fecha,
    channel: channel,
    packageName: packageName,
    referenceId: referenceId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('multi_app_dedup_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Modelos DedupRule, RecentMovementRecord y PendingTransactionItem', () {
    test('DedupRule soporta packages de forma retrocompatible', () {
      final legacyJson = <String, dynamic>{
        'merchant_key': 'exito laureles',
        'channels': ['app', 'sms'],
        'merge_window_hours': 48,
        'confirmations': 2,
        'created_at': '2026-11-15T10:00:00.000',
        'last_used_at': '2026-11-15T10:05:00.000',
      };

      final legacyRule = DedupRule.fromJson(legacyJson);
      expect(legacyRule.packages, isEmpty);
      expect(legacyRule.channels, equals(['app', 'sms']));
      expect(legacyRule.isMultiApp, isTrue);

      final updated = legacyRule.increment(
        extraChannels: ['correo'],
        extraPackages: ['com.bancolombia.personas', 'com.google.android.gm'],
        at: DateTime(2026, 11, 16, 12, 0),
      );
      expect(updated.confirmations, equals(3));
      expect(
        updated.packages,
        containsAll(['com.bancolombia.personas', 'com.google.android.gm']),
      );
      expect(updated.channels, containsAll(['app', 'sms', 'correo']));

      final roundTrip = DedupRule.fromJson(updated.toJson());
      expect(roundTrip.packages, equals(updated.packages));
      expect(roundTrip.channels, equals(updated.channels));
    });

    test('RecentMovementRecord y PendingTransactionItem preservan packageName',
        () {
      final item = _makePending(
        id: 'p1',
        monto: 120000,
        fecha: DateTime(2026, 11, 16, 9, 0),
        comercio: 'Transferencia',
        packageName: 'com.bancolombia.personas',
        channel: 'app',
      );
      final itemRt = PendingTransactionItem.fromJson(item.toJson());
      expect(itemRt.packageName, equals('com.bancolombia.personas'));

      final legacyItem = PendingTransactionItem.fromJson({
        'id': 'legacy_1',
        'raw_text': 'Compra \$50.000',
        'fecha': '2026-11-16T09:00:00.000',
        'classification': 'gasto',
        'confidence': 0.9,
        'requires_review': false,
        'auto_processable': true,
        'decision_source': 'deterministic_rules',
        'created_at': '2026-11-16T09:00:00.000',
      });
      expect(legacyItem.packageName, isNull);

      final rec = RecentMovementRecord(
        id: 'r1',
        amount: 200000,
        roundedAmount: 200000,
        timestamp: DateTime(2026, 11, 16, 9, 0),
        recordedAt: DateTime(2026, 11, 16, 9, 1),
        accountName: 'Bancolombia Ahorros',
        destinationAccount: 'Nequi',
        referenceId: 'UTR777',
        merchantKey: 'transferencia',
        packageName: 'com.bancolombia.personas',
        channel: 'app',
      );
      final recRt = RecentMovementRecord.fromJson(rec.toJson());
      expect(recRt.roundedAmount, equals(200000));
      expect(recRt.referenceId, equals('UTR777'));
      expect(recRt.packageName, equals('com.bancolombia.personas'));
      expect(recRt.destinationAccount, equals('Nequi'));
    });
  });

  group('Anillo de 48h en Hive cifrada y bloqueo de duplicados tardíos', () {
    test('Persiste hasta 100 entradas y poda registros > 48 h', () async {
      final enc = NotificationBoxEncryption(keyStore: _MemKeyStore());
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final rulesBox = await enc.openEncryptedBox('ring_rules_$suffix');
      final recentBox = await enc.openEncryptedBox('ring_recent_$suffix');
      addTearDown(() async {
        await rulesBox.close();
        await recentBox.close();
      });

      final correlator = TransactionDedupCorrelator(
        rulesBox: rulesBox,
        recentMovementsBox: recentBox,
      );

      final t0 = DateTime(2026, 11, 16, 10, 0);
      await correlator.recordConfirmedMovement(
        RecentMovementRecord(
          id: 'expired_old',
          amount: 10000,
          roundedAmount: 10000,
          timestamp: t0.subtract(const Duration(hours: 49)),
          recordedAt: t0.subtract(const Duration(hours: 49)),
          packageName: 'com.bancolombia.personas',
        ),
        now: t0,
      );

      for (var i = 0; i < 105; i++) {
        await correlator.recordConfirmedMovement(
          RecentMovementRecord(
            id: 'rec_$i',
            amount: 1000.0 + i,
            roundedAmount: 1000 + i,
            timestamp: t0.add(Duration(seconds: i)),
            recordedAt: t0.add(Duration(seconds: i)),
            packageName: 'com.bancolombia.personas',
          ),
          now: t0.add(Duration(seconds: i)),
        );
      }

      // Nuevo correlator leyendo desde la misma caja Hive cifrada
      final reloaded = TransactionDedupCorrelator(
        rulesBox: rulesBox,
        recentMovementsBox: recentBox,
      );
      final recent = await reloaded.getRecentMovements(
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(recent.length, equals(TransactionDedupCorrelator.maxRecentMovements));
      expect(recent.any((r) => r.id == 'expired_old'), isFalse);
      expect(recent.any((r) => r.id == 'rec_0'), isFalse);
      expect(recent.any((r) => r.id == 'rec_104'), isTrue);
    });

    test(
        'Bloquea aviso tardío solo con evidencia fuerte (referenceId o DedupRule multi-app <= 60m y distinto paquete/canal)',
        () async {
      final enc = NotificationBoxEncryption(keyStore: _MemKeyStore());
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final rulesBox = await enc.openEncryptedBox('late_rules_$suffix');
      final recentBox = await enc.openEncryptedBox('late_recent_$suffix');
      addTearDown(() async {
        await rulesBox.close();
        await recentBox.close();
      });

      final correlator = TransactionDedupCorrelator(
        rulesBox: rulesBox,
        recentMovementsBox: recentBox,
      );

      final t0 = DateTime(2026, 11, 16, 14, 0);
      await correlator.recordConfirmedMovement(
        RecentMovementRecord(
          id: 'conf_1',
          amount: 150000,
          roundedAmount: 150000,
          timestamp: t0,
          recordedAt: t0,
          referenceId: 'UTR9001',
          merchantKey: 'exito',
          packageName: 'com.bancolombia.personas',
          channel: 'app',
        ),
        now: t0,
      );

      // 1. Sin regla multi-app pero con mismo referenceId -> bloquea
      final byRef = await correlator.correlate(
        candidate: _makePending(
          id: 'late_ref',
          monto: 150000,
          fecha: t0.add(const Duration(minutes: 25)),
          comercio: 'Correo Bancolombia',
          packageName: 'com.google.android.gm',
          channel: 'correo',
          referenceId: 'UTR9001',
        ),
        existingPending: const [],
        now: t0.add(const Duration(minutes: 25)),
      );
      expect(
        byRef.decision,
        equals(CorrelationDecisionType.alreadyConfirmedDuplicate),
      );
      expect(byRef.shouldIgnoreAsAlreadyConfirmed, isTrue);
      expect(byRef.shouldMergeIntoExisting, isFalse);

      // 2. Sin referenceId ni regla multi-app aprendida -> NO bloquea
      final withoutRule = await correlator.correlate(
        candidate: _makePending(
          id: 'late_no_rule',
          monto: 150000,
          fecha: t0.add(const Duration(minutes: 15)),
          comercio: 'Correo Banco',
          packageName: 'com.google.android.gm',
          channel: 'correo',
        ),
        existingPending: const [],
        now: t0.add(const Duration(minutes: 15)),
      );
      expect(withoutRule.decision, equals(CorrelationDecisionType.unique));

      // 3. Con DedupRule multi-app aprendida, mismo monto, <= 60 min y distinto paquete -> bloquea
      await correlator.learnMergeRule(
        merchant: 'exito',
        channels: const ['app', 'correo'],
        packages: const ['com.bancolombia.personas', 'com.google.android.gm'],
        at: t0,
      );

      final withRule = await correlator.correlate(
        candidate: _makePending(
          id: 'late_with_rule',
          monto: 150000,
          fecha: t0.add(const Duration(minutes: 40)),
          comercio: 'Notificacion Gmail',
          packageName: 'com.google.android.gm',
          channel: 'correo',
        ),
        existingPending: const [],
        now: t0.add(const Duration(minutes: 40)),
      );
      expect(
        withRule.decision,
        equals(CorrelationDecisionType.alreadyConfirmedDuplicate),
      );

      // 4. Mismo paquete/canal (dos compras seguidas reales en la misma app) -> NO bloquea
      final samePkg = await correlator.correlate(
        candidate: _makePending(
          id: 'same_pkg',
          monto: 150000,
          fecha: t0.add(const Duration(minutes: 10)),
          comercio: 'Exito',
          packageName: 'com.bancolombia.personas',
          channel: 'app',
        ),
        existingPending: const [],
        now: t0.add(const Duration(minutes: 10)),
      );
      expect(samePkg.decision, equals(CorrelationDecisionType.unique));

      // 5. Fuera de ventana de 60 min -> NO bloquea
      final outsideWindow = await correlator.correlate(
        candidate: _makePending(
          id: 'late_90m',
          monto: 150000,
          fecha: t0.add(const Duration(minutes: 90)),
          comercio: 'Notificacion Gmail',
          packageName: 'com.google.android.gm',
          channel: 'correo',
        ),
        existingPending: const [],
        now: t0.add(const Duration(minutes: 90)),
      );
      expect(outsideWindow.decision, equals(CorrelationDecisionType.unique));
    });
  });

  group('Aprendizaje implícito 4 apps -> editar/confirmar 1 y descartar 3 -> siguiente agrupada',
      () {
    test(
        '4 apps notifican transferencia -> usuario corrige 1 y descarta 3 -> siguiente transferencia similar se agrupa en 1 tarjeta y bloquea aviso tardío tras confirmar',
        () async {
      SharedPreferences.setMockInitialValues({
        'accounts': [
          jsonEncode(AccountItem(
            icon: Icons.account_balance,
            title: 'Bancolombia Ahorros',
            subtitle: 'Ahorros *1111',
            balance: '2000000',
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
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final dedupBox = await enc.openEncryptedBox('m4_dedup_$suffix');
      final pendingBox = await enc.openEncryptedBox('m4_pending_$suffix');
      final executedBox = await enc.openEncryptedBox('m4_exec_$suffix');
      final patternsBox = await enc.openEncryptedBox('m4_pat_$suffix');
      final rulesBox = await enc.openEncryptedBox('m4_rules_$suffix');
      final recentBox = await enc.openEncryptedBox('m4_recent_$suffix');

      final source = _FakeNotificationSource();
      final execPort = _FakeExecutionPort();
      final whitelist = BankWhitelistService()
        ..addPackage('com.google.android.gm', bankName: 'Gmail')
        ..addPackage('com.google.android.apps.messaging', bankName: 'Mensajes');

      final pipeline = NotificationPipelineService(
        boxEncryption: enc,
        whitelistService: whitelist,
        source: source,
        executionPort: execPort,
        dedupBox: dedupBox,
        pendingBox: pendingBox,
        executedBox: executedBox,
        patternsBox: patternsBox,
        dedupRulesBox: rulesBox,
        recentMovementsBox: recentBox,
      );

      addTearDown(() async {
        await pipeline.dispose();
        await source.dispose();
        await dedupBox.close();
        await pendingBox.close();
        await executedBox.close();
        await patternsBox.close();
        await rulesBox.close();
        await recentBox.close();
      });

      await pipeline.initialize();
      await pipeline.setCaptureEnabled(true);

      // ─────────────────────────────────────────────────────────────────────
      // TRANSFERENCIA #1 ($250.000): 4 apps notifican con redacciones distintas
      // y quedan 4 tarjetas pendientes separadas en bandeja.
      // ─────────────────────────────────────────────────────────────────────
      final t1 = DateTime.now().subtract(const Duration(minutes: 5));
      source.emit(NotificationEvent(
        id: 't1_bancolombia',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Pagaste \$250.000 en App Personas',
        timestamp: t1,
      ));
      source.emit(NotificationEvent(
        id: 't1_nequi',
        packageName: 'com.nequi.MobileApp',
        title: 'Nequi',
        body: 'Pagaste \$250.000 en Billetera Movil',
        timestamp: t1.add(const Duration(seconds: 8)),
      ));
      source.emit(NotificationEvent(
        id: 't1_gmail',
        packageName: 'com.google.android.gm',
        title: 'Comprobante bancario',
        body: 'Cargo por \$250.000 en Portal Web',
        timestamp: t1.add(const Duration(seconds: 20)),
      ));
      source.emit(NotificationEvent(
        id: 't1_sms',
        packageName: 'com.google.android.apps.messaging',
        title: 'SMS Banco',
        body: 'Retiro aprobado por \$250.000 en Canal Electronico',
        timestamp: t1.add(const Duration(seconds: 35)),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pipeline.flushPendingProcessing();

      expect(pipeline.pendingNotifier.count, equals(4));
      final firstItems = List<PendingTransactionItem>.from(
        pipeline.pendingNotifier.items,
      );
      final primaryItem = firstItems.firstWhere(
        (i) => i.packageName == 'com.bancolombia.personas',
      );
      expect(primaryItem.packageName, equals('com.bancolombia.personas'));

      // Usuario edita/confirma 1 y descarta las otras 3
      final correctedOk = await pipeline.pendingNotifier.correctItem(
        id: primaryItem.id,
        newClassification: 'transferencia-propia',
        newCategory: 'Transferencia',
        newAccountName: 'Bancolombia Ahorros',
        newDestinationAccount: 'Nequi',
        newDescription: 'Transferencia propia',
      );
      expect(correctedOk, isTrue);
      expect(execPort.executed.length, equals(1));

      for (final other in firstItems.where((i) => i.id != primaryItem.id)) {
        final discarded = await pipeline.pendingNotifier.discardItem(other.id);
        expect(discarded, isTrue);
      }

      expect(pipeline.pendingNotifier.count, equals(0));
      // Descartar no ejecutó transacciones extra ni creó patrones en learned_patterns para las descartadas
      expect(execPort.executed.length, equals(1));

      // Verificar que se aprendió DedupRule multi-app con los 4 paquetes y 3 canales
      final learnedRule = await pipeline.dedupCorrelator.findDedupRule(
        primaryItem.merchantKey ?? primaryItem.comercio ?? '',
      );
      expect(learnedRule, isNotNull);
      expect(
        learnedRule!.packages,
        containsAll([
          'com.bancolombia.personas',
          'com.nequi.MobileApp',
          'com.google.android.gm',
          'com.google.android.apps.messaging',
        ]),
      );
      expect(learnedRule.channels, containsAll(['app', 'correo', 'sms']));

      // ─────────────────────────────────────────────────────────────────────
      // TRANSFERENCIA #2 ($380.000): mismas 4 apps notifican con textos distintos
      // -> debe agruparse automáticamente en 1 sola tarjeta con 4 groupedEvents
      // ─────────────────────────────────────────────────────────────────────
      final t2 = DateTime.now();
      source.emit(NotificationEvent(
        id: 't2_bancolombia',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Transferiste \$380.000 en Sucursal Movil',
        timestamp: t2,
      ));
      source.emit(NotificationEvent(
        id: 't2_nequi',
        packageName: 'com.nequi.MobileApp',
        title: 'Nequi',
        body: 'Recibiste \$380.000 en tu disponible',
        timestamp: t2.add(const Duration(seconds: 5)),
      ));
      source.emit(NotificationEvent(
        id: 't2_gmail',
        packageName: 'com.google.android.gm',
        title: 'Notificacion correo',
        body: 'Pago por \$380.000 en Pasarela Digital',
        timestamp: t2.add(const Duration(seconds: 15)),
      ));
      source.emit(NotificationEvent(
        id: 't2_sms',
        packageName: 'com.google.android.apps.messaging',
        title: 'SMS Alerta',
        body: 'Debito \$380.000 en Red Bancaria',
        timestamp: t2.add(const Duration(seconds: 25)),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pipeline.flushPendingProcessing();

      expect(pipeline.pendingNotifier.count, equals(1));
      final groupedCard = pipeline.pendingNotifier.items.single;
      expect(groupedCard.isGrouped, isTrue);
      expect(groupedCard.groupedCount, equals(4));
      expect(groupedCard.groupedEvents.length, equals(4));
      expect(groupedCard.strategicNote, contains('4 avisos'));
      expect(groupedCard.strategicNote, contains('app'));
      expect(groupedCard.strategicNote, contains('correo'));
      expect(groupedCard.strategicNote, contains('sms'));

      // La UI puede desagrupar los 4 avisos intactos y volver a agruparlos
      final splitOk =
          await pipeline.pendingNotifier.splitMergedItem(groupedCard.id);
      expect(splitOk, isTrue);
      expect(pipeline.pendingNotifier.count, equals(4));
      final splitIds = pipeline.pendingNotifier.items.map((i) => i.id).toList();
      final remerged = await pipeline.pendingNotifier.mergePendingItems(splitIds);
      expect(remerged, isNotNull);
      expect(pipeline.pendingNotifier.count, equals(1));

      // Confirmar la tarjeta agrupada de Transferencia #2
      final confirmT2 = await pipeline.pendingNotifier.confirmItem(remerged!.id);
      expect(confirmT2, isTrue);
      expect(pipeline.pendingNotifier.count, equals(0));
      expect(execPort.executed.length, equals(2));

      // ─────────────────────────────────────────────────────────────────────
      // AVISO TARDÍO tras confirmar (ej. correo diferido de otro remitente/regla):
      // Emitimos otro evento tardío de Gmail distinto pero mismo monto ($380.000)
      // con cuerpo distinto -> NO debe re-crear duplicado en bandeja.
      // Nota: confirmT2 tenía los 4 paquetes en groupedEvents; simulamos ahora
      // confirmación de solo Bancolombia y aviso tardío de Gmail en Transferencia #3.
      // ─────────────────────────────────────────────────────────────────────
      final t3 = DateTime.now().add(const Duration(minutes: 2));
      source.emit(NotificationEvent(
        id: 't3_bancolombia',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Transferiste \$410.000 en App Personas',
        timestamp: t3,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await pipeline.flushPendingProcessing();

      expect(pipeline.pendingNotifier.count, equals(1));
      final t3Item = pipeline.pendingNotifier.items.single;
      expect(await pipeline.pendingNotifier.confirmItem(t3Item.id), isTrue);
      expect(pipeline.pendingNotifier.count, equals(0));
      expect(execPort.executed.length, equals(3));

      // Llega correo tardío 12 min después para esa misma operación de $410.000
      source.emit(NotificationEvent(
        id: 't3_late_gmail',
        packageName: 'com.google.android.gm',
        title: 'Correo Bancolombia',
        body: 'Comprobante por \$410.000 en Portal Web',
        timestamp: t3.add(const Duration(minutes: 12)),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await pipeline.flushPendingProcessing();

      // Bloqueado contra el anillo de 48h -> bandeja permanece vacía
      expect(pipeline.pendingNotifier.count, equals(0));
      expect(execPort.executed.length, equals(3));
    });

    test(
        'No aprende regla multi-app si los descartes tienen monto distinto o >= 30 min',
        () async {
      final pendingBox = await Hive.openBox<dynamic>(
          'neg_pending_${DateTime.now().microsecondsSinceEpoch}');
      final rulesBox = await Hive.openBox<dynamic>(
          'neg_rules_${DateTime.now().microsecondsSinceEpoch}');
      addTearDown(() async {
        await pendingBox.close();
        await rulesBox.close();
      });

      final correlator = TransactionDedupCorrelator(rulesBox: rulesBox);
      final notifier = PendingTransactionsNotifier(
        box: pendingBox,
        executionPort: _FakeExecutionPort(),
        dedupCorrelator: correlator,
      );
      await notifier.initialize();

      final t = DateTime.now();
      await notifier.addPendingItems([
        _makePending(
          id: 'c1',
          monto: 50000,
          fecha: t,
          comercio: 'Tienda A',
          packageName: 'com.bancolombia.personas',
          channel: 'app',
        ),
        _makePending(
          id: 'd_diff_amount',
          monto: 75000,
          fecha: t.add(const Duration(minutes: 2)),
          comercio: 'Tienda B',
          packageName: 'com.google.android.gm',
          channel: 'correo',
        ),
        _makePending(
          id: 'd_late_35m',
          monto: 50000,
          fecha: t.add(const Duration(minutes: 35)),
          comercio: 'Tienda C',
          packageName: 'com.google.android.apps.messaging',
          channel: 'sms',
        ),
      ]);

      expect(await notifier.confirmItem('c1'), isTrue);
      expect(await notifier.discardItem('d_diff_amount'), isTrue);
      expect(await notifier.discardItem('d_late_35m'), isTrue);

      final rule = await correlator.findDedupRule('Tienda A');
      expect(rule, isNull);
    });

    test(
        'NotificationPipelineService propaga classification.strategicNote al crear PendingTransactionItem',
        () async {
      final enc = NotificationBoxEncryption(keyStore: _MemKeyStore());
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final dedupBox = await enc.openEncryptedBox('sn_dedup_$suffix');
      final pendingBox = await enc.openEncryptedBox('sn_pending_$suffix');
      final executedBox = await enc.openEncryptedBox('sn_exec_$suffix');
      final patternsBox = await enc.openEncryptedBox('sn_pat_$suffix');
      final rulesBox = await enc.openEncryptedBox('sn_rules_$suffix');
      final recentBox = await enc.openEncryptedBox('sn_recent_$suffix');
      final source = _FakeNotificationSource();

      const expectedNote =
          'Clasificado por patrón histórico (Alimentación · \$180.000 acumulados este mes)';
      final pipeline = NotificationPipelineService(
        boxEncryption: enc,
        whitelistService: BankWhitelistService(),
        source: source,
        executionPort: _FakeExecutionPort(),
        dedupBox: dedupBox,
        pendingBox: pendingBox,
        executedBox: executedBox,
        patternsBox: patternsBox,
        dedupRulesBox: rulesBox,
        recentMovementsBox: recentBox,
        classifier: _StubNoteClassifier(expectedNote),
      );

      addTearDown(() async {
        await pipeline.dispose();
        await source.dispose();
        await dedupBox.close();
        await pendingBox.close();
        await executedBox.close();
        await patternsBox.close();
        await rulesBox.close();
        await recentBox.close();
      });

      await pipeline.initialize();
      await pipeline.setCaptureEnabled(true);

      source.emit(NotificationEvent(
        id: 'sn_ev_1',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Compraste \$42.000 en Exito',
        timestamp: DateTime.now(),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await pipeline.flushPendingProcessing();

      expect(pipeline.pendingNotifier.count, equals(1));
      final item = pipeline.pendingNotifier.items.single;
      expect(item.strategicNote, equals(expectedNote));
      expect(item.packageName, equals('com.bancolombia.personas'));
    });
  });
}
