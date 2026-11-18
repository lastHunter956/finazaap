import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/Screens/settings_screen.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/services/ai_provider_config.dart';
import 'package:finazaap/themes/app_theme_data.dart';

class _InMemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late Directory tempDir;
  late _InMemorySecureKeyStore keyStore;
  late AiProviderConfigStore store;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_ai_settings_');
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
    keyStore = _InMemorySecureKeyStore();
    store = AiProviderConfigStore(keyStore: keyStore);
  });

  Future<void> pumpSettings(WidgetTester tester, {Size size = const Size(412, 915), double textScale = 1.0}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildThemeData(ThemeNotifier.activeMode),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: SettingsScreen(aiConfigStore: store),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pump(const Duration(milliseconds: 40));
      if (find.byType(Scrollable).evaluate().isNotEmpty) break;
    }
  }

  Future<void> addKeyViaDialog(
    WidgetTester tester, {
    required String providerName,
    required String label,
    required String rawKey,
    bool setPrimary = true,
  }) async {
    final addBtn = find.byKey(const Key('settings_ai_add_key_button'));
    await tester.scrollUntilVisible(addBtn, 250);
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai_key_dialog_provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(providerName).last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ai_key_dialog_label')), label);
    await tester.enterText(find.byKey(const Key('ai_key_dialog_secret')), rawKey);

    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const Key('ai_key_dialog_set_primary')),
    );
    if ((checkbox.value ?? false) != setPrimary) {
      await tester.tap(find.byKey(const Key('ai_key_dialog_set_primary')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('ai_key_dialog_save')));
    await tester.pumpAndSettle();
  }

  group('SettingsScreen - Panel Multi-IA y Proveedores', () {
    testWidgets(
      'permite agregar múltiples API keys (OpenRouter, NVIDIA NIM, OpenCode Zen), elegir IA Principal y persistir toggles',
      (tester) async {
        await pumpSettings(tester);

        await addKeyViaDialog(
          tester,
          providerName: 'OpenRouter',
          label: 'OR Gratis 1',
          rawKey: 'sk-or-v1-1111222233334444',
          setPrimary: true,
        );
        await addKeyViaDialog(
          tester,
          providerName: 'NVIDIA NIM (build.nvidia.com)',
          label: 'NVidia Principal',
          rawKey: 'nvapi-aaaa-bbbb-cccc-dddd',
          setPrimary: false,
        );
        await addKeyViaDialog(
          tester,
          providerName: 'OpenCode Zen',
          label: 'Zen Backup',
          rawKey: 'zen-key-9999888877776666',
          setPrimary: false,
        );

        expect(store.current.apiKeys.length, 3);
        expect(store.current.primaryProvider, AiProviderId.openRouter);
        expect(find.textContaining('OR Gratis 1'), findsOneWidget);
        expect(find.textContaining('NVidia Principal'), findsOneWidget);
        expect(find.textContaining('Zen Backup'), findsOneWidget);

        // Verificar secretos en SecureKeyStore en memoria
        expect(keyStore.values.length, 3);
        expect(
          keyStore.values.values,
          containsAll([
            'sk-or-v1-1111222233334444',
            'nvapi-aaaa-bbbb-cccc-dddd',
            'zen-key-9999888877776666',
          ]),
        );

        // Cambiar IA Principal desde el dropdown a NVIDIA NIM
        final dropdown = find.byKey(const Key('settings_ai_primary_provider_dropdown'));
        await tester.scrollUntilVisible(dropdown, -200);
        await tester.pumpAndSettle();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('NVIDIA NIM (build.nvidia.com)').last);
        await tester.pumpAndSettle();

        expect(store.current.primaryProvider, AiProviderId.nvidiaNim);

        // Cambiar toggles de rotación y respaldo cruzado
        final autoRotateFinder =
            find.byKey(const Key('settings_ai_auto_rotate_switch'));
        await tester.scrollUntilVisible(autoRotateFinder, 200);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: autoRotateFinder, matching: find.byType(Switch)),
        );
        await tester.pumpAndSettle();

        final crossFallbackFinder =
            find.byKey(const Key('settings_ai_cross_fallback_switch'));
        await tester.scrollUntilVisible(crossFallbackFinder, 200);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: crossFallbackFinder,
            matching: find.byType(Switch),
          ),
        );
        await tester.pumpAndSettle();

        expect(store.current.autoRotateFreeModels, isFalse);
        expect(store.current.crossProviderFallback, isTrue);

        // Probar botón Probar conexión / Ver modelos
        final probeBtn =
            find.byKey(const Key('settings_ai_test_connection_button'));
        await tester.scrollUntilVisible(probeBtn, 200);
        await tester.pumpAndSettle();
        await tester.tap(probeBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('settings_ai_probe_result_banner')),
          findsOneWidget,
        );

        // Verificar persistencia recargando una nueva instancia de AiProviderConfigStore
        final reloadedStore = AiProviderConfigStore(keyStore: keyStore);
        final reloaded = await reloadedStore.loadConfig(forceReload: true);
        expect(reloaded.primaryProvider, AiProviderId.nvidiaNim);
        expect(reloaded.apiKeys.length, 3);
        expect(reloaded.autoRotateFreeModels, isFalse);
        expect(reloaded.crossProviderFallback, isTrue);
      },
    );

    testWidgets(
      'renderiza sección Motor de IA en 360x640 @ TextScaler 1.35x sin overflow',
      (tester) async {
        await pumpSettings(
          tester,
          size: const Size(360, 640),
          textScale: 1.35,
        );

        final dropdown =
            find.byKey(const Key('settings_ai_primary_provider_dropdown'));
        await tester.scrollUntilVisible(dropdown, 250);
        await tester.pumpAndSettle();

        expect(dropdown, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
