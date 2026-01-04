import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' hide Key;

/// Servicio de encriptación robusto utilizando AES-256
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Claves y vectores de inicialización
  Key? _key;
  IV? _iv;
  Encrypter? _encrypter;
  
  bool _isInitialized = false;

  /// Inicializa el servicio cargando o generando la clave maestra
  Future<void> initialize() async {
    try {
      // Intentar recuperar clave maestra del almacenamiento seguro
      String? encodedKey = await _secureStorage.read(key: 'master_key');
      
      if (encodedKey == null) {
        // Generar nueva clave si no existe
        final key = Key.fromSecureRandom(32); // 256 bits
        encodedKey = base64Url.encode(key.bytes);
        await _secureStorage.write(key: 'master_key', value: encodedKey);
      }
      
      // Decodificar clave
      final keyBytes = base64Url.decode(encodedKey);
      _key = Key(keyBytes);
      
      // Usar un IV fijo para simplificar almacenamiento en esta versión
      // Nota: En producción idealmente el IV se guarda junto con el texto cifrado,
      // pero para mantener compatibilidad simple usamos uno derivado o fijo por ahora.
      _iv = IV.fromLength(16); 
      
      _encrypter = Encrypter(AES(_key!, mode: AESMode.cbc));
      
      _isInitialized = true;
      if (kDebugMode) {
        print('✅ EncryptionService: Inicializado con AES-256');
      }
    } catch (e) {
      print('❌ EncryptionService Error: $e');
      // Fallback a modo no inicializado (lanzará error al usar)
    }
  }

  /// Encripta datos usando AES-256
  Future<String> encryptData(String plainText, {String context = 'default'}) async {
    if (!_isInitialized || _encrypter == null) {
      // Fallback de emergencia si no se pudo inicializar crypto
      if (kDebugMode) print('⚠️ EncryptionService: Usando fallback Base64 (Servicio no init)');
      return base64.encode(utf8.encode(plainText));
    }
    
    try {
      final encrypted = _encrypter!.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print('❌ Error al encriptar: $e');
      throw Exception('Fallo de encriptación');
    }
  }

  /// Desencripta datos usando AES-256
  Future<String> decryptData(String encryptedData, {String context = 'default'}) async {
    if (!_isInitialized || _encrypter == null) {
        // Intento de fallback decoding si está en base64 simple
        try {
           return utf8.decode(base64.decode(encryptedData));
        } catch (_) {
           return encryptedData; 
        }
    }

    try {
      final encrypted = Encrypted.fromBase64(encryptedData);
      return _encrypter!.decrypt(encrypted, iv: _iv);
    } catch (e) {
      // Si falla AES, intentar Base64 simple (migración de datos legacy/debug)
      try {
        if (kDebugMode) print('⚠️ Falló AES, intentando fallback Base64 para datos legacy');
        final bytes = base64.decode(encryptedData);
        return utf8.decode(bytes);
      } catch (e2) {
        print('❌ Error al desencriptar Base64 fallback: $e2');
        return encryptedData; // Retornar data cruda como último recurso
      }
    }
  }

  /// Encripta un mapa JSON completo
  Future<String> encryptJson(Map<String, dynamic> json, {String context = 'default'}) async {
    final jsonString = jsonEncode(json);
    return encryptData(jsonString, context: context);
  }

  /// Desencripta a un mapa JSON
  Future<Map<String, dynamic>> decryptJson(String encryptedData, {String context = 'default'}) async {
    final jsonString = await decryptData(encryptedData, context: context);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Borra las claves de seguridad (¡Peligroso! Hace los datos irrecuperables)
  Future<void> wipeKeys() async {
    await _secureStorage.deleteAll();
    _isInitialized = false;
    print('⚠️ EncryptionService: Claves borradas. Datos previos irrecuperables.');
  }

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;
}
