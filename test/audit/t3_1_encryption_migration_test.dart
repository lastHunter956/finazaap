import 'dart:io';

import 'package:finazaap/core/security/encryption_service.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/services/data_management_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryEncryptionKeyStore implements EncryptionKeyStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Nota arquitectónica verificada en T3.1:
  // `EncryptionService.encryptData` usa AES-256-GCM autenticado (IV aleatorio de 12 B
  // prefijado al payload) mientras `HiveAesCipher` (hive 2.2.3) usa AES-256-CBC + PKCS7
  // sin HMAC-SHA256 (solo CRC32 en formato Hive). No son equivalentes y protegen capas distintas.

  late Directory tempDir;
  late _InMemoryEncryptionKeyStore keyStore;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_t3_1_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
  });

  setUp(() async {
    keyStore = _InMemoryEncryptionKeyStore();
    EncryptionService().configureForTesting(keyStore);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await Hive.close();
    for (final entity in tempDir.listSync()) {
      entity.deleteSync(recursive: true);
    }
    EncryptionService().resetToDefaultForTesting();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('T3.1 EncryptionService AES-GCM & fail-closed', () {
    test('falla cerrado (StateError) si no está inicializado', () async {
      final service = EncryptionService();
      expect(service.isInitialized, isFalse);

      await expectLater(
        () => service.encryptData('secreto'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => service.decryptData('c2VjcmV0bw=='),
        throwsA(isA<StateError>()),
      );
    });

    test('cifrar dos veces el mismo texto produce salidas distintas (IV aleatorio) y descifra correctamente', () async {
      final service = EncryptionService();
      await service.initialize();

      const plainText = 'Saldo sintético COP 125000';
      final c1 = await service.encryptData(plainText);
      final c2 = await service.encryptData(plainText);

      expect(c1, isNot(equals(c2)));
      expect(await service.decryptData(c1), equals(plainText));
      expect(await service.decryptData(c2), equals(plainText));
    });

    test('decryptData falla cerrado ante payload corrupto o manipulado (sin fallback Base64)', () async {
      final service = EncryptionService();
      await service.initialize();

      final validCipher = await service.encryptData('dato-integridad');
      // Alterar último carácter del payload Base64
      final tampered = validCipher.substring(0, validCipher.length - 2) +
          (validCipher.endsWith('AA') ? 'BB' : 'AA');

      await expectLater(
        () => service.decryptData(tampered),
        throwsA(anything),
      );
      await expectLater(
        () => service.decryptData('dGV4dG8tcGxhbm8='), // Base64 plano
        throwsA(anything),
      );
    });

    test('wipeKeys borra únicamente master_key y preserva otras llaves', () async {
      final service = EncryptionService();
      await keyStore.write('user_pin_hash_v2', 'hash-sintetico');
      await service.initialize();

      expect(keyStore.data.containsKey(EncryptionService.masterKeyStorageKey), isTrue);
      await service.wipeKeys();

      expect(service.isInitialized, isFalse);
      expect(keyStore.data.containsKey(EncryptionService.masterKeyStorageKey), isFalse);
      expect(keyStore.data['user_pin_hash_v2'], equals('hash-sintetico'));
    });
  });

  group('T3.1 Migración segura de cajas Hive e idempotencia', () {
    test('migra caja sintética data y responsibilities en claro a HiveAesCipher conservando 100% de registros', () async {
      // 1. Crear cajas sintéticas en texto plano
      final plainDataBox = await Hive.openBox<Add_data>('data');
      await plainDataBox.add(
        Add_data(
          'Expenses',
          '45000',
          DateTime(2026, 11, 10),
          'Supermercado',
          'Compra sintética',
          'Cuenta Prueba',
          123,
        ),
      );
      await plainDataBox.close();

      final plainRespBox = await Hive.openBox<Responsibility>('responsibilities');
      await plainRespBox.add(
        Responsibility(
          id: 'resp-1',
          name: 'Internet Sintético',
          amount: 80000,
          dueDay: 15,
          category: 'servicio',
          frequency: 'mensual',
          iconCode: 456,
        ),
      );
      await plainRespBox.close();

      // 2. Inicializar EncryptionService y abrir/migrar cajas cifradas
      await EncryptionService().initialize();
      final encDataBox = await EncryptionService().openEncryptedBox<Add_data>('data');
      await ResponsibilityService.init();
      final encRespBox = ResponsibilityService.getBox();

      expect(encDataBox.length, equals(1));
      expect(encDataBox.getAt(0)!.amount, equals('45000'));
      expect(encDataBox.getAt(0)!.detail, equals('Supermercado'));

      expect(encRespBox.length, equals(1));
      expect(encRespBox.getAt(0)!.name, equals('Internet Sintético'));
      expect(encRespBox.getAt(0)!.amount, equals(80000));

      // 3. Reapertura idempotente tras cerrar Hive
      await Hive.close();
      final reopenedDataBox = await EncryptionService().openEncryptedBox<Add_data>('data');
      expect(reopenedDataBox.length, equals(1));
      expect(reopenedDataBox.getAt(0)!.explain, equals('Compra sintética'));
    });

    test('recupera 100% de registros si una migración fue interrumpida en staging', () async {
      await EncryptionService().initialize();
      final cipher = EncryptionService().getHiveCipher();

      // Simular estado interrumpido: staging cifrado presente y caja destino aún ausente
      final staging = await Hive.openBox<Add_data>('data_enc_tmp', encryptionCipher: cipher);
      await staging.add(
        Add_data(
          'Income',
          '150000',
          DateTime(2026, 11, 12),
          'Nómina',
          'Recuperación staging',
          'Cuenta Prueba',
          999,
        ),
      );
      await staging.close();

      final recoveredBox = await EncryptionService().openEncryptedBox<Add_data>('data');
      expect(recoveredBox.length, equals(1));
      expect(recoveredBox.getAt(0)!.amount, equals('150000'));
      expect(recoveredBox.getAt(0)!.explain, equals('Recuperación staging'));
      expect(await Hive.boxExists('data_enc_tmp'), isFalse);
    });

    test('deleteAllData limpia cajas cifradas y claves ai_* en SharedPreferences', () async {
      await EncryptionService().initialize();
      final dataBox = await EncryptionService().openEncryptedBox<Add_data>('data');
      await dataBox.add(
        Add_data('Expenses', '1000', DateTime(2026, 11, 1), 'Cafe', 'Test', 'Cuenta', 1),
      );
      await ResponsibilityService.init();
      await ResponsibilityService.getBox().add(
        Responsibility(
          id: 'r1',
          name: 'Servicio',
          amount: 500,
          dueDay: 1,
          category: 'servicio',
          frequency: 'mensual',
          iconCode: 1,
        ),
      );

      SharedPreferences.setMockInitialValues({
        'accounts': ['["Cuenta"]'],
        'available_balance': 1000.0,
        'ai_chat_history': ['hola'],
        'ai_user_notes': 'nota',
        'ai_model_url': 'https://example.invalid/model',
      });

      final deleted = await DataManagementService().deleteAllData();
      expect(deleted, isTrue);
      expect(dataBox.isEmpty, isTrue);
      expect(ResponsibilityService.getBox().isEmpty, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('accounts'), isFalse);
      expect(prefs.containsKey('ai_chat_history'), isFalse);
      expect(prefs.containsKey('ai_user_notes'), isFalse);
      expect(prefs.containsKey('ai_model_url'), isFalse);
    });
  });
}
