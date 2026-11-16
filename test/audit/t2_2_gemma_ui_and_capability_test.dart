import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/ai_chat_screen.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:finazaap/services/device_capability_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T2.2 - DeviceCapabilityResult & MethodChannel', () {
    const channel = MethodChannel('com.example.finazaap/device_info');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('rechaza cuando availRAMGB < 2.0 aunque totalRAMGB >= 4.0', () {
      const result = DeviceCapabilityResult(
        freeStorageGB: 8.0,
        totalRAMGB: 6.0,
        availRAMGB: 1.4,
        lowMemory: false,
        isArm64: true,
      );

      expect(result.hasEnoughRAM, isTrue);
      expect(result.hasEnoughAvailableRAM, isFalse);
      expect(result.canRunModel, isFalse);
    });

    test('rechaza cuando lowMemory es true aunque availRAMGB >= 2.0', () {
      const result = DeviceCapabilityResult(
        freeStorageGB: 8.0,
        totalRAMGB: 6.0,
        availRAMGB: 2.5,
        lowMemory: true,
        isArm64: true,
      );

      expect(result.hasEnoughAvailableRAM, isFalse);
      expect(result.canRunModel, isFalse);
    });

    test('acepta cuando totalRAMGB >= 4.0, availRAMGB >= 2.0, lowMemory false, almacenamiento y arm64 OK', () {
      const result = DeviceCapabilityResult(
        freeStorageGB: 8.0,
        totalRAMGB: 6.0,
        availRAMGB: 2.8,
        lowMemory: false,
        isArm64: true,
      );

      expect(result.hasEnoughStorage, isTrue);
      expect(result.hasEnoughRAM, isTrue);
      expect(result.hasEnoughAvailableRAM, isTrue);
      expect(result.hasCompatProcessor, isTrue);
      expect(result.canRunModel, isTrue);
    });

    test('DeviceCapabilityService.check lee getDeviceMemoryInfo correctamente', () async {
      const oneGB = 1000 * 1000 * 1000;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getFreeDiskSpace') {
          return 10.0;
        }
        if (call.method == 'getDeviceMemoryInfo') {
          return <String, dynamic>{
            'totalMem': 6 * oneGB,
            'availMem': (2.5 * oneGB).round(),
            'lowMemory': false,
          };
        }
        return null;
      });

      final cap = await DeviceCapabilityService.check();
      expect(cap.freeStorageGB, closeTo(10.0, 0.01));
      expect(cap.totalRAMGB, closeTo(6.0, 0.05));
      expect(cap.availRAMGB, closeTo(2.5, 0.05));
      expect(cap.lowMemory, isFalse);
      expect(cap.hasEnoughAvailableRAM, isTrue);
    });
  });

  group('T2.2 - AiChatScreen conserva URL ante rebuilds', () {
    late Directory tempDir;

    setUpAll(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tempDir = await Directory.systemTemp.createTemp('moneo_t2_2_chat_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AdddataAdapter());
      }
    });

    setUp(() async {
      AiChatService().resetCapabilityStateForTest();
      SharedPreferences.setMockInitialValues({'ai_use_local_simulator': false});
      await Hive.openBox<Add_data>('data');
      await AiChatService().setSimulatorMode(false);
    });

    tearDown(() async {
      DeviceCapabilityService.checkOverride = null;
      AiChatService().resetCapabilityStateForTest();
      await AiChatService().setSimulatorMode(true);
      await Hive.close();
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
      'preserva texto en _modelUrlController tras notifyListeners()',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(AppThemeMode.defaultDark),
            home: const AiChatScreen(),
          ),
        );

        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }

        final urlField = find.byType(TextField).first;
        expect(urlField, findsOneWidget);

        const typedUrl = 'https://example.com/gemma-4-e2b-it.litertlm';
        await tester.enterText(urlField, typedUrl);
        await tester.pump();

        // Provoca rebuild del banner desde AiChatService.notifyListeners()
        await AiChatService().updateLearnedPatterns();
        await tester.pump();

        expect(find.text(typedUrl), findsOneWidget);
      },
    );

    testWidgets(
      'muestra 4a fila RAM disponible y Reintentar verificación cuando solo falta RAM libre sin autodescarga',
      (tester) async {
        DeviceCapabilityService.checkOverride = () async =>
            const DeviceCapabilityResult(
              freeStorageGB: 32.9,
              totalRAMGB: 7.6,
              availRAMGB: 1.4,
              lowMemory: false,
              isArm64: true,
            );
        addTearDown(() => DeviceCapabilityService.checkOverride = null);

        final service = AiChatService();
        service.resetDownloadMetrics();
        await service.recheckDeviceCapability();

        expect(service.deviceCapability, isNotNull);
        expect(service.deviceCapability!.hasEnoughStorage, isTrue);
        expect(service.deviceCapability!.hasEnoughRAM, isTrue);
        expect(service.deviceCapability!.hasCompatProcessor, isTrue);
        expect(service.deviceCapability!.hasEnoughAvailableRAM, isFalse);
        expect(service.gemmaError, contains('RAM disp'));
        expect(service.downloadAttemptCount, 0);
        expect(service.networkRequestCount, 0);

        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(AppThemeMode.defaultDark),
            home: const AiChatScreen(),
          ),
        );

        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }

        expect(find.textContaining('RAM disponible: 1.4 GB'), findsOneWidget);
        expect(
          find.text('RAM disponible insuficiente en este momento'),
          findsOneWidget,
        );
        expect(find.text('Reintentar verificación'), findsOneWidget);
      },
    );

    testWidgets(
      'pre-carga URL por defecto editable y permite restaurarla sin autodescarga',
      (tester) async {
        DeviceCapabilityService.checkOverride = () async =>
            const DeviceCapabilityResult(
              freeStorageGB: 32.9,
              totalRAMGB: 7.6,
              availRAMGB: 2.8,
              lowMemory: false,
              isArm64: true,
            );
        addTearDown(() => DeviceCapabilityService.checkOverride = null);

        final service = AiChatService();
        service.resetDownloadMetrics();
        await service.recheckDeviceCapability();

        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(AppThemeMode.defaultDark),
            home: const AiChatScreen(),
          ),
        );

        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }

        final urlField = find.byType(TextField).first;
        expect(urlField, findsOneWidget);
        expect(
          tester.widget<TextField>(urlField).controller?.text,
          AiChatService.defaultModelUrl,
        );
        expect(find.text('Descargar'), findsOneWidget);
        expect(find.text('Restaurar modelo por defecto'), findsOneWidget);
        expect(service.downloadAttemptCount, 0);

        const customUrl = 'https://example.com/custom-gemma.litertlm';
        await tester.enterText(urlField, customUrl);
        await tester.pump();
        expect(
          tester.widget<TextField>(urlField).controller?.text,
          customUrl,
        );

        await tester.ensureVisible(find.text('Restaurar modelo por defecto'));
        await tester.tap(find.text('Restaurar modelo por defecto'));
        await tester.pump();
        expect(
          tester.widget<TextField>(urlField).controller?.text,
          AiChatService.defaultModelUrl,
        );
        expect(service.downloadAttemptCount, 0);
      },
    );

    testWidgets(
      'muestra aviso informativo neutro (sin ícono/título rojo de error) cuando Modelo no descargado',
      (tester) async {
        DeviceCapabilityService.checkOverride = () async =>
            const DeviceCapabilityResult(
              freeStorageGB: 32.9,
              totalRAMGB: 7.6,
              availRAMGB: 2.8,
              lowMemory: false,
              isArm64: true,
            );
        addTearDown(() => DeviceCapabilityService.checkOverride = null);

        final service = AiChatService();
        service.resetDownloadMetrics();
        service.isModelInstalledOverride = (_) async => false;
        addTearDown(() => service.isModelInstalledOverride = null);

        await service.recheckDeviceCapability();

        expect(service.gemmaError, contains('Modelo no descargado'));
        expect(service.downloadAttemptCount, 0);

        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(AppThemeMode.defaultDark),
            home: const AiChatScreen(),
          ),
        );

        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }

        expect(find.textContaining('Error al inicializar Gemma IA:'), findsNothing);
        expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
        expect(find.byIcon(Icons.info_outline_rounded), findsAtLeastNWidgets(1));
        expect(find.textContaining('Modelo no descargado'), findsOneWidget);
        expect(find.text('Descargar'), findsOneWidget);
        final urlField = find.byType(TextField).first;
        expect(
          tester.widget<TextField>(urlField).controller?.text,
          AiChatService.defaultModelUrl,
        );
        expect(service.downloadAttemptCount, 0);
      },
    );
  });
}
