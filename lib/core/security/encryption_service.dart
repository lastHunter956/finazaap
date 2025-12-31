import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de encriptación SIMPLIFICADO (Modo Debug/No-Encryption)
/// 
/// NOTA: Se ha desactivado la encriptación AES-256 compleja por solicitud del usuario
/// para enfocarse en la corrección de bugs.
/// 
/// Esta versión utiliza codificación Base64 simple para mantener la compatibilidad
/// con la arquitectura existente sin la complejidad de crypto/encrypt.
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isInitialized = false;

  /// Inicializa el servicio (Simulado)
  Future<void> initialize() async {
    print('⚠️ EncryptionService: Encriptación compleja DESACTIVADA por debug');
    _isInitialized = true;
  }

  /// "Encripta" datos usando Base64 (Reemplazo temporal)
  Future<String> encryptData(String plainText, {String context = 'default'}) async {
    // Simplemente codificamos en Base64 para que no sea texto plano visualmente
    // pero SIN seguridad real criptográfica por ahora
    final bytes = utf8.encode(plainText);
    return base64.encode(bytes);
  }

  /// "Desencripta" datos usando Base64 (Reemplazo temporal)
  Future<String> decryptData(String encryptedData, {String context = 'default'}) async {
    try {
      final bytes = base64.decode(encryptedData);
      return utf8.decode(bytes);
    } catch (e) {
      print('❌ Error al decodificar Base64: $e');
      return encryptedData; // Retornar el dato original si falla (fallback)
    }
  }

  /// "Encripta" un mapa JSON completo
  Future<String> encryptJson(Map<String, dynamic> json, {String context = 'default'}) async {
    final jsonString = jsonEncode(json);
    return encryptData(jsonString, context: context);
  }

  /// "Desencripta" a un mapa JSON
  Future<Map<String, dynamic>> decryptJson(String encryptedData, {String context = 'default'}) async {
    final jsonString = await decryptData(encryptedData, context: context);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Wipe keys (Simulado)
  Future<void> wipeKeys() async {
    print('⚠️ EncryptionService: Wipe solicitado (No-Op en modo debug)');
  }

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;
}
