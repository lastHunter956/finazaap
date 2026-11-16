import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/gemma_classifier_adapter.dart';
import 'package:finazaap/features/notifications/services/learned_patterns_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';

class _CountingFailingGemmaClient implements GemmaInferenceClient {
  int isModelLoadedCalls = 0;
  int generateCalls = 0;
  bool shouldSucceed = false;
  bool throwOnGenerate = false;

  @override
  Future<bool> isModelLoaded() async {
    isModelLoadedCalls++;
    return true;
  }

  @override
  Future<String?> generateResponse(String prompt) async {
    generateCalls++;
    if (throwOnGenerate) {
      throw StateError('Gemma hardware error');
    }
    if (!shouldSucceed) {
      return null;
    }
    return '{"classification":"gasto","category":"Alimentación","confidence":0.91}';
  }
}

class _MemKeyStore implements SecureKeyStore {
  final Map<String, String> _map = {};
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
  @override
  Future<void> delete(String key) async => _map.remove(key);
}

class _DummyExecPort implements TransactionExecutionPort {
  @override
  Future<TransactionExecutionResult> execute(
          TransactionExecutionRequest request) async =>
      const TransactionExecutionResult.success(transactionId: 'tx_ttl');

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

class _DummySource implements NotificationSourcePort {
  @override
  Stream<NotificationEvent> get notificationStream => const Stream.empty();
  @override
  Future<NotificationSourceStatus> checkStatus() async =>
      const NotificationSourceStatus(
        isListening: false,
        permissionStatus: NotificationPermissionStatus.granted,
      );
  @override
  Future<bool> startListening() async => true;
  @override
  Future<void> stopListening() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GemmaClassifierAdapter - Circuit-Breaker', () {
    test(
        'Se abre tras 2 fallos y retorna null en 0ms durante cooldown sin invocar al cliente',
        () async {
      var now = DateTime(2026, 11, 16, 12, 0);
      final client = _CountingFailingGemmaClient()..throwOnGenerate = true;
      final adapter = GemmaClassifierAdapter(
        client: client,
        failureThreshold: 2,
        cooldownDuration: const Duration(minutes: 5),
        nowProvider: () => now,
      );

      // Fallo 1
      expect(
        await adapter.classify(rawText: 'Compra en comercio X'),
        isNull,
      );
      expect(adapter.consecutiveFailures, equals(1));
      expect(adapter.isCircuitOpen, isFalse);

      // Fallo 2 -> abre el circuit-breaker
      expect(
        await adapter.classify(rawText: 'Compra en comercio Y'),
        isNull,
      );
      expect(adapter.consecutiveFailures, equals(2));
      expect(adapter.isCircuitOpen, isTrue);

      final callsBeforeCooldown = client.generateCalls;
      final sw = Stopwatch()..start();
      final duringCooldown = await adapter.classify(rawText: 'Compra Z');
      sw.stop();

      expect(duringCooldown, isNull);
      expect(client.generateCalls, equals(callsBeforeCooldown));
      expect(sw.elapsedMilliseconds, lessThan(20));

      // Tras expirar el cooldown, permite reintentar y resetea si tiene éxito
      now = now.add(const Duration(minutes: 6));
      expect(adapter.isCircuitOpen, isFalse);
      client.throwOnGenerate = false;
      client.shouldSucceed = true;

      final recovered = await adapter.classify(rawText: 'Compra recuperada');
      expect(recovered, isNotNull);
      expect(recovered!.classification, equals('gasto'));
      expect(adapter.consecutiveFailures, equals(0));
      expect(adapter.isCircuitOpen, isFalse);
    });
  });

  group('NotificationPipelineService - Poda TTL y box.compact()', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('ttl_prune_test_');
      Hive.init(tempDir.path);
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        'initialize() poda notification_dedup_history (>30d), notification_executed_ids (>90d y tope 500) y learned_patterns obsoletos (>180d)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final enc = NotificationBoxEncryption(keyStore: _MemKeyStore());
      final dedupBox = await enc.openEncryptedBox('ttl_dedup');
      final pendingBox = await enc.openEncryptedBox('ttl_pending');
      final executedBox = await enc.openEncryptedBox('ttl_executed');
      final patternsBox = await enc.openEncryptedBox('ttl_patterns');
      final rulesBox = await enc.openEncryptedBox('ttl_rules');

      final now = DateTime.now();

      // 1. notification_dedup_history: 1 viejo (>30d) + 1 reciente
      await dedupBox.put(
        'old_dedup',
        now.subtract(const Duration(days: 35)).toIso8601String(),
      );
      await dedupBox.put(
        'fresh_dedup',
        now.subtract(const Duration(days: 2)).toIso8601String(),
      );

      // 2. notification_executed_ids: 1 viejo (>90d) + 505 recientes (tope 500)
      await executedBox.put('old_exec', {
        'executed_at': now.subtract(const Duration(days: 95)).toIso8601String(),
      });
      for (var i = 0; i < 505; i++) {
        await executedBox.put('exec_$i', {
          'executed_at':
              now.subtract(Duration(minutes: i + 1)).toIso8601String(),
        });
      }

      // 3. learned_patterns: 1 obsoleto (>180d) + 1 reciente
      final patternsSvc = LearnedPatternsService(box: patternsBox);
      await patternsSvc.recordConfirmation(
        merchant: 'Viejo Comercio',
        category: 'Otros',
        at: now.subtract(const Duration(days: 190)),
      );
      await patternsSvc.recordConfirmation(
        merchant: 'Nuevo Comercio',
        category: 'Alimentación',
        at: now.subtract(const Duration(days: 3)),
      );

      final pipeline = NotificationPipelineService(
        boxEncryption: enc,
        whitelistService: BankWhitelistService(),
        source: _DummySource(),
        executionPort: _DummyExecPort(),
        dedupBox: dedupBox,
        pendingBox: pendingBox,
        executedBox: executedBox,
        patternsBox: patternsBox,
        dedupRulesBox: rulesBox,
      );

      addTearDown(() async {
        await pipeline.dispose();
        await dedupBox.close();
        await pendingBox.close();
        await executedBox.close();
        await patternsBox.close();
        await rulesBox.close();
      });

      await pipeline.initialize();

      expect(dedupBox.containsKey('old_dedup'), isFalse);
      expect(dedupBox.containsKey('fresh_dedup'), isTrue);

      expect(executedBox.containsKey('old_exec'), isFalse);
      expect(executedBox.length, equals(500));

      expect(await patternsSvc.findPattern('Viejo Comercio'), isNull);
      expect(await patternsSvc.findPattern('Nuevo Comercio'), isNotNull);
    });
  });
}
