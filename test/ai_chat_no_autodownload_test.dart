import 'dart:io';

import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_ai_nodl_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
    await Hive.openBox<Add_data>('data');
    await ResponsibilityService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
      'Abrir Chat / initialize y setSimulatorMode(false) no intentan descarga automática ni transfieren bytes',
      () async {
    SharedPreferences.setMockInitialValues({
      'ai_use_local_simulator': false,
      'ai_model_url': 'https://example.invalid/gemma.litertlm',
    });

    final service = AiChatService();
    service.resetDownloadMetrics();
    service.isModelInstalledOverride = (_) async => false;
    service.networkDownloadOverride = (_, __) async => 2048;

    await service.initialize();

    expect(service.downloadAttemptCount, 0);
    expect(service.networkRequestCount, 0);
    expect(service.bytesTransferred, 0);
    expect(service.isDownloading, isFalse);

    await service.setSimulatorMode(false);

    expect(service.downloadAttemptCount, 0);
    expect(service.networkRequestCount, 0);
    expect(service.bytesTransferred, 0);
    expect(service.isDownloading, isFalse);
  });

  test(
      'Solo la descarga explícita vía setModelUrl registra intento, petición de red y bytes transferidos',
      () async {
    SharedPreferences.setMockInitialValues({
      'ai_use_local_simulator': false,
    });

    final service = AiChatService();
    service.resetDownloadMetrics();
    service.isModelInstalledOverride = (_) async => false;
    service.networkDownloadOverride = (_, onProgress) async {
      onProgress(0.5);
      onProgress(1.0);
      return 1024;
    };

    await service.setModelUrl('https://example.invalid/gemma.litertlm');

    expect(service.downloadAttemptCount, 1);
    expect(service.networkRequestCount, 1);
    expect(service.bytesTransferred, 1024);
    expect(service.isDownloading, isFalse);
  });
}
