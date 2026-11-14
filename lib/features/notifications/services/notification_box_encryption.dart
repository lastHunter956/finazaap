import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Abstracción mínima para almacenamiento seguro de llaves criptográficas.
/// Permite inyectar un almacén en memoria en pruebas unitarias sin canal nativo.
abstract class SecureKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyStore implements SecureKeyStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureKeyStore([
    FlutterSecureStorage? storage,
  ]) : _storage = storage ??
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

/// Gestiona el cifrado AES-256 (`HiveAesCipher`) exclusivamente para las cajas
/// del módulo de notificaciones (`pending_notifications`, `learned_patterns`,
/// `notification_dedup_history`).
///
/// No modifica `lib/core/security/encryption_service.dart` ni las cajas legadas
/// de Moneo (`data`, `accounts`, etc.).
class NotificationBoxEncryption {
  static const String keyStorageKey = 'moneo_notifications_hive_key_v1';

  final SecureKeyStore _keyStore;
  Uint8List? _cachedKey;

  NotificationBoxEncryption({SecureKeyStore? keyStore})
      : _keyStore = keyStore ?? const FlutterSecureKeyStore();

  /// Obtiene o genera una clave AES-256 de 32 bytes almacenada en [SecureKeyStore].
  Future<Uint8List> getOrCreateKey() async {
    if (_cachedKey != null && _cachedKey!.length == 32) {
      return _cachedKey!;
    }

    final encoded = await _keyStore.read(keyStorageKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = base64Url.decode(encoded);
        if (decoded.length == 32) {
          _cachedKey = Uint8List.fromList(decoded);
          return _cachedKey!;
        }
      } catch (_) {
        // Clave corrupta; se regenerará abajo.
      }
    }

    final generated = Uint8List.fromList(Hive.generateSecureKey());
    await _keyStore.write(keyStorageKey, base64Url.encode(generated));
    _cachedKey = generated;
    return generated;
  }

  /// Abre una caja Hive cifrada con AES-256.
  ///
  /// Si existe una caja previa sin cifrar con el mismo nombre, migra sus
  /// entradas sin pérdida a una caja cifrada antes de abrirla con [HiveAesCipher]
  /// (evitando que Hive descarte registros al detectar frames no cifrados).
  Future<Box<dynamic>> openEncryptedBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName);
    }

    final key = await getOrCreateKey();
    final cipher = HiveAesCipher(key);
    final markerKey = 'enc_ready_$boxName';
    final alreadyEncrypted = (await _keyStore.read(markerKey)) == '1';

    if (!alreadyEncrypted && await Hive.boxExists(boxName)) {
      final migratedBox = await _migratePlaintextBoxToEncrypted(boxName, cipher);
      await _keyStore.write(markerKey, '1');
      return migratedBox;
    }

    final box = await Hive.openBox<dynamic>(
      boxName,
      encryptionCipher: cipher,
    );
    if (!alreadyEncrypted) {
      await _keyStore.write(markerKey, '1');
    }
    return box;
  }

  Future<Box<dynamic>> _migratePlaintextBoxToEncrypted(
    String boxName,
    HiveAesCipher cipher,
  ) async {
    final backup = <dynamic, dynamic>{};
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<dynamic>(boxName).close();
      }
      final legacyBox = await Hive.openBox<dynamic>(boxName);
      for (final k in legacyBox.keys) {
        backup[k] = legacyBox.get(k);
      }
      await legacyBox.deleteFromDisk();
    } catch (_) {
      // Si tampoco se puede abrir sin cifrado, recrea caja limpia cifrada.
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {}
    }

    final encryptedBox = await Hive.openBox<dynamic>(
      boxName,
      encryptionCipher: cipher,
    );
    if (backup.isNotEmpty) {
      await encryptedBox.putAll(backup);
    }
    return encryptedBox;
  }

  /// Elimina completamente las cajas cifradas de notificaciones del disco.
  Future<void> deleteBoxes(List<String> boxNames) async {
    for (final name in boxNames) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box<dynamic>(name).clear();
          await Hive.box<dynamic>(name).close();
        }
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // Continuar con las demás cajas
      }
    }
  }
}
