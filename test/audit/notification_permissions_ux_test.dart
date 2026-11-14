import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/settings_screen.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:finazaap/services/notification_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService - Permisos POST_NOTIFICATIONS y SCHEDULE_EXACT_ALARM', () {
    final service = NotificationService();

    tearDown(() {
      service.testCheckNotificationsEnabled = null;
      service.testRequestNotificationsPermission = null;
      service.testCanScheduleExactAlarms = null;
      service.testRequestExactAlarmsPermission = null;
    });

    test('no solicita alarmas exactas si POST_NOTIFICATIONS sigue denegado y re-verifica estado real', () async {
      var exactAlarmRequested = false;
      var checkCalls = 0;

      service.testCheckNotificationsEnabled = () async {
        checkCalls++;
        return false;
      };
      service.testRequestNotificationsPermission = () async => false;
      service.testCanScheduleExactAlarms = () async => false;
      service.testRequestExactAlarmsPermission = () async {
        exactAlarmRequested = true;
        return true;
      };

      final result = await service.requestPermissionDetailed();
      expect(result.notificationsGranted, isFalse);
      expect(result.exactAlarmsGranted, isFalse);
      expect(exactAlarmRequested, isFalse);
      expect(checkCalls, 2);
    });

    test('activa recordatorios aunque SCHEDULE_EXACT_ALARM sea false si POST_NOTIFICATIONS es true', () async {
      service.testCheckNotificationsEnabled = () async => true;
      service.testCanScheduleExactAlarms = () async => false;
      service.testRequestExactAlarmsPermission = () async => false;

      final result = await service.requestPermissionDetailed();
      expect(result.notificationsGranted, isTrue);
      expect(result.exactAlarmsGranted, isFalse);
      expect(result.isGranted, isTrue);
    });
  });

  group('BankWhitelistService & SettingsScreen - Diagnóstico y re-evaluación al volver de Ajustes', () {
    const channel = MethodChannel('com.example.finazaap/notifications_apps');
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    late Directory tempDir;
    final Map<String, String> mockSecureStorage = {};

    setUpAll(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tempDir = await Directory.systemTemp.createTemp('moneo_perm_ux_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AdddataAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ResponsibilityAdapter());
      }
      await Hive.openBox<Add_data>('data');
      await Hive.openBox<Responsibility>('responsibilities');
    });

    setUp(() async {
      mockSecureStorage.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return key != null ? mockSecureStorage[key] : null;
          case 'write':
            if (key != null && args['value'] != null) {
              mockSecureStorage[key] = args['value'].toString();
            }
            return null;
          case 'delete':
            if (key != null) mockSecureStorage.remove(key);
            return null;
          case 'readAll':
            return Map<String, String>.from(mockSecureStorage);
          default:
            return null;
        }
      });
      SharedPreferences.setMockInitialValues({'notifications_enabled': false});
      await Hive.box<Add_data>('data').clear();
      await Hive.box<Responsibility>('responsibilities').clear();
    });

    tearDown(() async {
      NotificationService().testCheckNotificationsEnabled = null;
      NotificationService().testRequestNotificationsPermission = null;
      NotificationService().testCanScheduleExactAlarms = null;
      NotificationService().testRequestExactAlarmsPermission = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
    });

    tearDownAll(() async {
      if (Hive.isBoxOpen('data')) {
        await Hive.box<Add_data>('data').close();
      }
      if (Hive.isBoxOpen('responsibilities')) {
        await Hive.box<Responsibility>('responsibilities').close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('BankWhitelistService.getListenerDiagnostics lee restrictedSettingsBlocked', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getListenerDiagnostics') {
          return <String, dynamic>{
            'permissionGranted': false,
            'listenerConnected': false,
            'batteryOptimizationIgnored': true,
            'restrictedSettingsBlocked': true,
          };
        }
        return null;
      });

      final diag = await BankWhitelistService().getListenerDiagnostics();
      expect(diag['permissionGranted'], isFalse);
      expect(diag['restrictedSettingsBlocked'], isTrue);
    });

    testWidgets(
      'SettingsScreen activa Recordatorios al regresar (resumed) si el usuario concedió permiso en Ajustes',
      (tester) async {
        var notificationsEnabled = false;
        var openedNotificationSettings = false;

        NotificationService().testCheckNotificationsEnabled =
            () async => notificationsEnabled;
        NotificationService().testRequestNotificationsPermission = () async => false;
        NotificationService().testCanScheduleExactAlarms = () async => true;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getListenerDiagnostics') {
            return <String, dynamic>{
              'permissionGranted': false,
              'listenerConnected': false,
              'batteryOptimizationIgnored': true,
              'restrictedSettingsBlocked': true,
            };
          }
          if (call.method == 'openAppNotificationSettings') {
            openedNotificationSettings = true;
            return true;
          }
          return null;
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(AppThemeMode.defaultDark),
            home: const SettingsScreen(),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (find.byType(Scrollable).evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.byType(Scrollable), findsOneWidget);

        final reminderText = find.text('Recordatorios de Pagos');
        await tester.scrollUntilVisible(
          reminderText,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 80));
        final reminderSwitch = find.ancestor(
          of: reminderText,
          matching: find.byType(SwitchListTile),
        );
        await tester.tap(reminderSwitch);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }

        expect(find.text('Permiso de notificaciones requerido'), findsOneWidget);
        await tester.tap(find.text('Abrir Ajustes'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
        expect(openedNotificationSettings, isTrue);

        // El usuario habilita notificaciones en Ajustes y vuelve a la app.
        notificationsEnabled = true;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notifications_enabled'), isTrue);

        // Permitir que el timer de AlertHelper cierre limpiamente antes de tearDown.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
