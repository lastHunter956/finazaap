import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' hide Key;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';

/// Abstracción mínima para almacenamiento seguro de llaves y marcadores.
/// Permite inyectar un almacén en memoria en pruebas unitarias sin canal nativo.
abstract class EncryptionKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureEncryptionKeyStore implements EncryptionKeyStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureEncryptionKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Servicio de encriptación fail-closed para Moneo.
///
/// Resolución arquitectónica de cifrado por capa:
/// - Payloads de texto/JSON (`encryptData` / `decryptData`): usan **AES-256-GCM**
///   (`AESMode.gcm`) con IV aleatorio de 12 bytes por operación prefijado al
///   payload (`[IV (12 B) | ciphertext + authTag]`) codificado en Base64.
/// - Cajas Hive (`getHiveCipher` / `openEncryptedBox`): usan `HiveAesCipher`
///   con la clave maestra de 32 bytes. `HiveAesCipher` NO es equivalente a
///   AES-GCM: Hive implementa cifrado por frame con **AES-256-CBC + PKCS7**
///   e integridad **HMAC-SHA256**.
class EncryptionService {
  static const String masterKeyStorageKey = 'master_key';
  static const int _ivLengthBytes = 12;

  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  EncryptionKeyStore _keyStore = const FlutterSecureEncryptionKeyStore();
  Key? _key;
  Encrypter? _encrypter;
  bool _isInitialized = false;

  /// Permite configurar un [EncryptionKeyStore] en memoria para pruebas aisladas.
  @visibleForTesting
  void configureForTesting(EncryptionKeyStore keyStore) {
    _keyStore = keyStore;
    _key = null;
    _encrypter = null;
    _isInitialized = false;
  }

  /// Restablece el almacén por defecto tras pruebas.
  @visibleForTesting
  void resetToDefaultForTesting() {
    _keyStore = const FlutterSecureEncryptionKeyStore();
    _key = null;
    _encrypter = null;
    _isInitialized = false;
  }

  /// Inicializa el servicio cargando o generando la clave maestra AES-256.
  /// Lanza excepción si no puede acceder al almacén seguro (fail-closed).
  Future<void> initialize() async {
    String? encodedKey = await _keyStore.read(masterKeyStorageKey);

    if (encodedKey == null || encodedKey.isEmpty) {
      final key = Key.fromSecureRandom(32); // 256 bits
      encodedKey = base64Url.encode(key.bytes);
      await _keyStore.write(masterKeyStorageKey, encodedKey);
    }

    final keyBytes = base64Url.decode(encodedKey);
    if (keyBytes.length != 32) {
      throw StateError(
        'Clave maestra inválida: se esperaban 32 bytes y se obtuvieron ${keyBytes.length}.',
      );
    }

    _key = Key(Uint8List.fromList(keyBytes));
    _encrypter = Encrypter(AES(_key!, mode: AESMode.gcm));
    _isInitialized = true;
  }

  /// Encripta datos usando AES-256-GCM con IV aleatorio de 12 bytes por operación.
  /// Falla cerrado (`StateError`) si el servicio no está inicializado.
  Future<String> encryptData(
    String plainText, {
    String context = 'default',
  }) async {
    if (!_isInitialized || _encrypter == null) {
      throw StateError(
        'EncryptionService no inicializado; operación de cifrado denegada (fail-closed).',
      );
    }

    final iv = IV.fromSecureRandom(_ivLengthBytes);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    final combined = Uint8List(_ivLengthBytes + encrypted.bytes.length)
      ..setRange(0, _ivLengthBytes, iv.bytes)
      ..setRange(_ivLengthBytes, _ivLengthBytes + encrypted.bytes.length, encrypted.bytes);
    return base64.encode(combined);
  }

  /// Desencripta datos cifrados con AES-256-GCM (`[IV (12 B) | ciphertext + tag]`).
  /// Falla cerrado ante datos corruptos, manipulados o servicio no inicializado.
  Future<String> decryptData(
    String encryptedData, {
    String context = 'default',
  }) async {
    if (!_isInitialized || _encrypter == null) {
      throw StateError(
        'EncryptionService no inicializado; operación de descifrado denegada (fail-closed).',
      );
    }

    final Uint8List combined;
    try {
      combined = base64.decode(encryptedData);
    } on FormatException catch (e) {
      throw FormatException('Payload cifrado Base64 inválido: $e');
    }

    if (combined.length <= _ivLengthBytes) {
      throw const FormatException(
        'Payload cifrado inválido: longitud insuficiente para IV y ciphertext.',
      );
    }

    final iv = IV(Uint8List.sublistView(combined, 0, _ivLengthBytes));
    final cipherBytes = Uint8List.sublistView(combined, _ivLengthBytes);
    return _encrypter!.decrypt(Encrypted(cipherBytes), iv: iv);
  }

  /// Encripta un mapa JSON completo usando AES-256-GCM.
  Future<String> encryptJson(
    Map<String, dynamic> json, {
    String context = 'default',
  }) async {
    return encryptData(jsonEncode(json), context: context);
  }

  /// Desencripta a un mapa JSON usando AES-256-GCM.
  Future<Map<String, dynamic>> decryptJson(
    String encryptedData, {
    String context = 'default',
  }) async {
    final jsonString = await decryptData(encryptedData, context: context);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Retorna el cifrador `HiveAesCipher` (AES-256-CBC + PKCS7 + HMAC-SHA256)
  /// respaldado por la clave maestra de 32 bytes.
  HiveAesCipher getHiveCipher() {
    if (!_isInitialized || _key == null) {
      throw StateError(
        'EncryptionService no inicializado; no se puede crear HiveAesCipher.',
      );
    }
    return HiveAesCipher(_key!.bytes);
  }

  /// Abre una caja Hive cifrada con `HiveAesCipher`, migrando de forma
  /// idempotente y recuperable ante interrupciones si existía en claro.
  Future<Box<T>> openEncryptedBox<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }

    if (!_isInitialized) {
      await initialize();
    }

    final cipher = getHiveCipher();
    final markerKey = 'hive_enc_v1_$boxName';
    final stagingName = '${boxName}_enc_tmp';
    final alreadyEncrypted = (await _keyStore.read(markerKey)) == '1';

    // 1. Recuperación ante interrupción previa de migración.
    if (await Hive.boxExists(stagingName)) {
      if (!await Hive.boxExists(boxName)) {
        // La migración se interrumpió tras borrar la caja en claro y antes de
        // finalizar la copia hacia la caja cifrada definitiva.
        final stagingBox = await Hive.openBox<T>(
          stagingName,
          encryptionCipher: cipher,
        );
        final recovered = <dynamic, T>{};
        for (final k in stagingBox.keys) {
          final v = stagingBox.get(k);
          if (v != null) recovered[k] = _detachForBox(v);
        }
        await stagingBox.close();

        final targetBox = await Hive.openBox<T>(
          boxName,
          encryptionCipher: cipher,
        );
        if (recovered.isNotEmpty) {
          await targetBox.putAll(recovered);
          await targetBox.flush();
        }
        await Hive.deleteBoxFromDisk(stagingName);
        await _keyStore.write(markerKey, '1');
        return targetBox;
      } else {
        // La caja original aún existe; limpiar staging incompleto y continuar.
        await Hive.deleteBoxFromDisk(stagingName);
      }
    }

    // 2. Si la caja existe sin marcador de cifrado, migrar desde texto plano.
    if (!alreadyEncrypted && await Hive.boxExists(boxName)) {
      return _migratePlaintextBoxToEncrypted<T>(
        boxName: boxName,
        stagingName: stagingName,
        markerKey: markerKey,
        cipher: cipher,
      );
    }

    // 3. Apertura normal cifrada.
    final box = await Hive.openBox<T>(boxName, encryptionCipher: cipher);
    if (!alreadyEncrypted) {
      await _keyStore.write(markerKey, '1');
    }
    return box;
  }

  Future<Box<T>> _migratePlaintextBoxToEncrypted<T>({
    required String boxName,
    required String stagingName,
    required String markerKey,
    required HiveAesCipher cipher,
  }) async {
    final entries = <dynamic, T>{};

    try {
      final legacyBox = await Hive.openBox<T>(boxName);
      for (final k in legacyBox.keys) {
        final v = legacyBox.get(k);
        if (v != null) {
          entries[k] = _detachForBox(v);
        }
      }
      await legacyBox.close();
    } catch (_) {
      // Si la caja ya estaba cifrada con la clave actual (ej. marcador perdido),
      // intentar abrir directamente con el cifrador antes de asumir corrupción.
      final directBox = await Hive.openBox<T>(
        boxName,
        encryptionCipher: cipher,
      );
      await _keyStore.write(markerKey, '1');
      return directBox;
    }

    // Fase 1: Persistir respaldo cifrado en staging antes de borrar la caja en claro.
    if (await Hive.boxExists(stagingName)) {
      await Hive.deleteBoxFromDisk(stagingName);
    }
    final stagingBox = await Hive.openBox<T>(
      stagingName,
      encryptionCipher: cipher,
    );
    if (entries.isNotEmpty) {
      await stagingBox.putAll(entries);
      await stagingBox.flush();
    }
    await stagingBox.close();

    // Fase 2: Reemplazar la caja en claro por la caja definitiva cifrada.
    await Hive.deleteBoxFromDisk(boxName);
    final encryptedBox = await Hive.openBox<T>(
      boxName,
      encryptionCipher: cipher,
    );
    if (entries.isNotEmpty) {
      await encryptedBox.putAll(
        entries.map((k, v) => MapEntry(k, _detachForBox(v))),
      );
      await encryptedBox.flush();
    }

    // Fase 3: Eliminar staging y registrar marcador idempotente.
    await Hive.deleteBoxFromDisk(stagingName);
    await _keyStore.write(markerKey, '1');
    return encryptedBox;
  }

  T _detachForBox<T>(T value) {
    if (value is Add_data) {
      return Add_data(
        value.IN,
        value.amount,
        value.datetime,
        value.detail,
        value.explain,
        value.name,
        value.iconCode,
        value.installments,
        value.isInterestFree,
        value.responsibilityId,
        value.isObligationPayment,
      ) as T;
    }
    if (value is Responsibility) {
      return Responsibility(
        id: value.id,
        name: value.name,
        amount: value.amount,
        dueDay: value.dueDay,
        category: value.category,
        frequency: value.frequency,
        isPaid: value.isPaid,
        lastPaymentDate: value.lastPaymentDate,
        iconCode: value.iconCode,
        cardLimit: value.cardLimit,
        cardBalance: value.cardBalance,
        minimumPayment: value.minimumPayment,
        cutoffDay: value.cutoffDay,
        paymentDay: value.paymentDay,
        interestRate: value.interestRate,
        installments: value.installments,
        installmentPlansJson: value.installmentPlansJson,
        paidAmountThisMonth: value.paidAmountThisMonth,
        lastPaymentMonth: value.lastPaymentMonth,
        lastPaymentYear: value.lastPaymentYear,
        paymentDates: value.paymentDates != null
            ? List<DateTime>.from(value.paymentDates!)
            : null,
      ) as T;
    }
    return value;
  }

  /// Borra únicamente `'master_key'` sin eliminar llaves de PIN u otros módulos.
  Future<void> wipeKeys() async {
    await _keyStore.delete(masterKeyStorageKey);
    _key = null;
    _encrypter = null;
    _isInitialized = false;
  }

  /// Verifica si el servicio está inicializado.
  bool get isInitialized => _isInitialized;
}
