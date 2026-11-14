import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/features/notifications/adapters/mock_transaction_execution_adapter.dart';
import 'package:finazaap/features/notifications/domain/models/notification_event.dart';
import 'package:finazaap/features/notifications/domain/ports/notification_source_port.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t1_4_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'accounts': [
        jsonEncode({
          'title': 'Ahorros',
          'subtitle': 'Cuenta Bancaria',
          'balance': '500000.0',
          'icon': Icons.account_balance.codePoint,
          'iconColor': Colors.blue.value,
          'includeInTotal': true,
        }),
      ],
      'available_balance': 500000.0,
      'default_currency': 'COP',
      NotificationPipelineService.captureEnabledPrefsKey: true,
      NotificationPipelineService.autoAcceptFuturePrefsKey: false,
    });
    await PrefsManager.init();
    final prefs = await PrefsManager.instance;
    await prefs.reload();

    if (Hive.isBoxOpen('data')) {
      await Hive.box<Add_data>('data').clear();
    } else {
      await Hive.openBox<Add_data>('data');
    }
    if (Hive.isBoxOpen('responsibilities')) {
      await Hive.box<Responsibility>('responsibilities').clear();
    } else {
      await ResponsibilityService.init();
      await Hive.box<Responsibility>('responsibilities').clear();
    }
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 2), onTimeout: () => <void>[]);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('T1.4a: Pipeline combina parseResult.requiresReview y min(confidence)', () async {
    final encryption = NotificationBoxEncryption(keyStore: _InMemorySecureKeyStore());
    final whitelist = BankWhitelistService();
    await whitelist.setBankEnabled('com.bancolombia.personas', true);

    final source = _SyntheticNotificationSource();
    final dedupBox = await Hive.openBox<dynamic>('t14_dedup');
    final pendingBox = await Hive.openBox<dynamic>('t14_pending');
    final executedBox = await Hive.openBox<dynamic>('t14_executed');
    final patternsBox = await Hive.openBox<dynamic>('t14_patterns');

    final pipeline = NotificationPipelineService(
      boxEncryption: encryption,
      whitelistService: whitelist,
      source: source,
      executionPort: MockTransactionExecutionAdapter(),
      dedupBox: dedupBox,
      pendingBox: pendingBox,
      executedBox: executedBox,
      patternsBox: patternsBox,
    );
    await pipeline.initialize();
    await pipeline.setCaptureEnabled(true);

    addTearDown(() async {
      await source.dispose();
      await dedupBox.close();
      await pendingBox.close();
      await executedBox.close();
      await patternsBox.close();
    });

    source.emit(NotificationEvent(
      id: 'evt_1',
      packageName: 'com.bancolombia.personas',
      title: 'Bancolombia',
      body: 'Compra por \$50.50 en Tienda X',
      timestamp: DateTime(2026, 5, 10, 12, 0),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final items = pipeline.pendingNotifier.items;
    expect(items.length, 1);
    final item = items.first;
    expect(item.requiresReview, isTrue);
    expect(item.isEligibleForAcceptAll, isFalse);
  });

  test('T1.4b: CategoryService.addCategoryWithMetadata limpia deleted_expense_categories al recrear', () async {
    await CategoryService.addCategoryWithMetadata(
      'Expenses',
      'Mascotas',
      Icons.pets.codePoint,
      Colors.teal.value,
    );
    await CategoryService.deleteCategory('Expenses', 'Mascotas');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(CategoryService.deletedExpenseCategoriesKey), contains('Mascotas'));

    await CategoryService.addCategoryWithMetadata(
      'Expenses',
      'Mascotas',
      Icons.pets.codePoint,
      Colors.teal.value,
    );

    expect(prefs.getStringList(CategoryService.deletedExpenseCategoriesKey), isNot(contains('Mascotas')));
    final cats = await CategoryService.getCategoriesWithMetadata('Expenses');
    expect(cats.any((c) => c['text'] == 'Mascotas'), isTrue);
  });

  test('T1.4c: AiChatService.acceptTransactionSuggestion no guarda en Hive si processTransaction falla', () async {
    final prefs = await PrefsManager.instance;
    await prefs.setStringList('accounts', []);

    final chatService = AiChatService();
    await chatService.acceptTransactionSuggestion(0, {
      'type': 'Expenses',
      'amount': 45000.0,
      'category': 'Comida',
      'account': 'Cuenta Inexistente',
      'detail': 'Almuerzo',
      'date': '2026-05-10',
    });

    expect(Hive.box<Add_data>('data').length, 0);
  });
}
