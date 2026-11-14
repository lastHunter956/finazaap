import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/features/notifications/adapters/android_notification_source.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/domain/ports/transaction_execution_port.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';

class _InMemoryKeyStore implements SecureKeyStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }
}

class _FakeExecutionPort implements TransactionExecutionPort {
  @override
  Future<TransactionExecutionResult> execute(
    TransactionExecutionRequest request,
  ) async {
    return const TransactionExecutionResult.success(transactionId: 'tx_1');
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

class _BurstSource implements NotificationSourcePort {
  final StreamController<NotificationEvent> _controller =
      StreamController<NotificationEvent>.broadcast();
  bool _listening = false;

  @override
  Stream<NotificationEvent> get notificationStream => _controller.stream;

  @override
  Future<NotificationSourceStatus> checkStatus() async {
    return NotificationSourceStatus(
      isListening: _listening,
      permissionStatus: NotificationPermissionStatus.granted,
    );
  }

  @override
  Future<bool> startListening() async {
    _listening = true;
    return true;
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  void emitBatch(List<NotificationEvent> events) {
    for (final event in events) {
      _controller.add(event);
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_pipeline_unit_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'accounts': [
        jsonEncode(AccountItem(
          icon: Icons.account_balance,
          title: 'Bancolombia Ahorros',
          subtitle: 'Cuenta de Ahorros',
          balance: '950000.0',
          iconColor: Colors.blue,
        ).toJson()),
      ],
    });
  });

  test('procesa ráfagas de notificaciones de forma secuencial y sin duplicados',
      () async {
    final encryption = NotificationBoxEncryption(keyStore: _InMemoryKeyStore());
    final dedupBox = await encryption.openEncryptedBox('unit_pipe_dedup');
    final pendingBox = await encryption.openEncryptedBox('unit_pipe_pending');
    final executedBox = await encryption.openEncryptedBox('unit_pipe_executed');
    final patternsBox = await encryption.openEncryptedBox('unit_pipe_patterns');

    final source = _BurstSource();
    final whitelist = BankWhitelistService();
    final pipeline = NotificationPipelineService(
      boxEncryption: encryption,
      whitelistService: whitelist,
      source: source,
      executionPort: _FakeExecutionPort(),
      dedupBox: dedupBox,
      pendingBox: pendingBox,
      executedBox: executedBox,
      patternsBox: patternsBox,
    );

    await pipeline.initialize();
    await pipeline.setCaptureEnabled(true);

    final baseTime = DateTime(2026, 11, 13, 14, 0);
    source.emitBatch([
      NotificationEvent(
        id: 'b1',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Compraste \$20.000 en Exito desde Bancolombia Ahorros',
        timestamp: baseTime,
      ),
      // Duplicado exacto dentro de la ventana de 5 min (mismo monto/comercio)
      NotificationEvent(
        id: 'b1_dup',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Compraste \$20.000 en Exito desde Bancolombia Ahorros',
        timestamp: baseTime.add(const Duration(seconds: 15)),
      ),
      NotificationEvent(
        id: 'b2',
        packageName: 'com.bancolombia.personas',
        title: 'Bancolombia',
        body: 'Compraste \$35.000 en Farmatodo desde Bancolombia Ahorros',
        timestamp: baseTime.add(const Duration(seconds: 30)),
      ),
    ]);

    // Permitir entrega de microtasks de los dos broadcast streams antes de drenar la cadena FIFO.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await pipeline.flushPendingProcessing();

    expect(pipeline.pendingNotifier.count, equals(2));
    expect(
      pipeline.pendingNotifier.items.map((i) => i.monto).toSet(),
      equals({20000.0, 35000.0}),
    );

    await pipeline.dispose();
    await source.dispose();
    await encryption.deleteBoxes([
      'unit_pipe_dedup',
      'unit_pipe_pending',
      'unit_pipe_executed',
      'unit_pipe_patterns',
    ]);
  });

  group('Diagnósticos nativos del listener y canal de apps', () {
    const channel = MethodChannel('com.example.finazaap/notifications_apps');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
        'BankWhitelistService lee getListenerDiagnostics, forceRefresh y openBatteryOptimizationSettings',
        () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'getListenerDiagnostics':
            return <String, dynamic>{
              'permissionGranted': true,
              'listenerConnected': true,
              'batteryOptimizationIgnored': false,
            };
          case 'openBatteryOptimizationSettings':
            return true;
          case 'getInstalledApps':
            return <Map<String, dynamic>>[
              {
                'packageName': 'com.bancolombia.personas',
                'appName': 'Bancolombia',
              },
            ];
          default:
            return null;
        }
      });

      final whitelist = BankWhitelistService();
      final diag = await whitelist.getListenerDiagnostics();
      expect(diag['permissionGranted'], isTrue);
      expect(diag['listenerConnected'], isTrue);
      expect(diag['batteryOptimizationIgnored'], isFalse);

      final opened = await whitelist.openBatteryOptimizationSettings();
      expect(opened, isTrue);

      final apps = await whitelist.getInstalledApps(forceRefresh: true);
      expect(apps.length, equals(1));
      expect(calls.last.method, equals('getInstalledApps'));
      expect(calls.last.arguments, equals({'forceRefresh': true}));
    });

    test('getListenerDiagnostics hace fallback seguro sin plugin', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      final whitelist = BankWhitelistService();
      final diag = await whitelist.getListenerDiagnostics();
      expect(diag['permissionGranted'], isFalse);
      expect(diag['listenerConnected'], isFalse);
      expect(diag['batteryOptimizationIgnored'], isTrue);

      final androidSource = AndroidNotificationSource();
      final sourceDiag = await androidSource.getListenerDiagnostics();
      expect(sourceDiag['permissionGranted'], isFalse);
      expect(sourceDiag['batteryOptimizationIgnored'], isTrue);
      androidSource.dispose();
    });
  });
}
