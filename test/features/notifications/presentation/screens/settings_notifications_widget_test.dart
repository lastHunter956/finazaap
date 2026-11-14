import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/Screens/settings_screen.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/themes/app_theme_data.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_settings_widget_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeNotifier.init();
  });

  Widget buildTestableSettings() {
    return MaterialApp(
      theme: buildThemeData(ThemeNotifier.activeMode),
      home: const SettingsScreen(),
    );
  }

  testWidgets(
      'SettingsScreen muestra controles reales de notificaciones, consentimiento y auto-aceptar desactivado por defecto',
      (tester) async {
    await tester.pumpWidget(buildTestableSettings());
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(Scrollable).evaluate().isNotEmpty) break;
    }

    final captureSwitchFinder =
        find.byKey(const Key('settings_bank_capture_switch'));
    await tester.scrollUntilVisible(captureSwitchFinder, 200);
    expect(captureSwitchFinder, findsOneWidget);
    final SwitchListTile captureSwitch = tester.widget(captureSwitchFinder);
    expect(captureSwitch.value, isFalse);

    final inboxFinder = find.byKey(const Key('settings_real_inbox_tile'));
    expect(inboxFinder, findsOneWidget);

    final autoAcceptFinder =
        find.byKey(const Key('settings_auto_accept_future_switch'));
    await tester.scrollUntilVisible(autoAcceptFinder, 200);
    expect(autoAcceptFinder, findsOneWidget);
    final SwitchListTile autoAcceptSwitch = tester.widget(autoAcceptFinder);
    expect(autoAcceptSwitch.value, isFalse);

    expect(
      find.byKey(const Key('settings_learned_patterns_tile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_wipe_notifications_tile')),
      findsOneWidget,
    );

    // Tocar el switch de captura debe abrir el diálogo de consentimiento/privacidad
    await tester.scrollUntilVisible(captureSwitchFinder, -200);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: captureSwitchFinder, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Captura de notificaciones bancarias'),
      findsOneWidget,
    );
    expect(find.textContaining('AES-256'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    final SwitchListTile captureAfterCancel =
        tester.widget(captureSwitchFinder);
    expect(captureAfterCancel.value, isFalse);
  });
}
