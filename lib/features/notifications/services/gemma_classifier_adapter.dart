import 'dart:async';
import 'dart:convert';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Resultado estructurado emitido por el clasificador Gemma on-device.
class GemmaClassificationResult {
  final String classification; // 'gasto' | 'ingreso' | 'transferencia-propia'
  final String? category;
  final double confidence;

  const GemmaClassificationResult({
    required this.classification,
    this.category,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'classification': classification,
        'category': category,
        'confidence': confidence,
      };

  factory GemmaClassificationResult.fromJson(Map<String, dynamic> json) {
    return GemmaClassificationResult(
      classification: json['classification'] as String,
      category: json['category'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.82,
    );
  }

  @override
  String toString() =>
      'GemmaClassificationResult(classification: $classification, category: $category, confidence: $confidence)';
}

/// Contrato para el cliente de inferencia Gemma.
/// Permite inyectar mocks o implementaciones simuladas en pruebas sin cargar modelos pesados.
abstract class GemmaInferenceClient {
  Future<bool> isModelLoaded();
  Future<String?> generateResponse(String prompt);
}

/// Implementación por defecto que invoca `FlutterGemma` en dispositivos reales.
class DefaultGemmaInferenceClient implements GemmaInferenceClient {
  InferenceModel? _model;

  @override
  Future<bool> isModelLoaded() async {
    try {
      if (_model != null) return true;
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 256,
        preferredBackend: PreferredBackend.gpu,
      );
      return _model != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> generateResponse(String prompt) async {
    try {
      final loaded = await isModelLoaded();
      if (!loaded || _model == null) return null;

      final chat = await _model!.createChat(
        systemInstruction:
            'Eres un clasificador contable offline para finanzas personales. '
            'Responde UNICAMENTE con un objeto JSON valido.',
        maxOutputTokens: 128,
      );
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();
      if (response is TextResponse) {
        return response.token;
      } else if (response is ThinkingResponse) {
        return response.content;
      } else {
        return response.toString();
      }
    } catch (_) {
      return null;
    }
  }
}

/// Adaptador para clasificación mediante Gemma on-device (Etapa 3).
///
/// Solo se debe invocar cuando las reglas deterministas y los patrones aprendidos
/// no alcanzan el umbral de certeza (confidence < 0.80).
/// Posee aislamiento con timeout estricto (3 segundos) para proteger la fluidez de la app.
class GemmaClassifierAdapter {
  final GemmaInferenceClient _client;
  final Duration timeout;

  GemmaClassifierAdapter({
    GemmaInferenceClient? client,
    this.timeout = const Duration(seconds: 3),
  }) : _client = client ?? DefaultGemmaInferenceClient();

  /// Verifica si el modelo Gemma está listo para inferir en memoria.
  Future<bool> isAvailable() async {
    try {
      return await _client.isModelLoaded().timeout(timeout);
    } catch (_) {
      return false;
    }
  }

  /// Ejecuta la clasificación con Gemma de forma segura.
  /// Retorna `null` si Gemma no está disponible, falla o excede el tiempo límite.
  Future<GemmaClassificationResult?> classify({
    required String rawText,
    String? merchant,
    double? amount,
  }) async {
    try {
      return await _executeClassification(
        rawText: rawText,
        merchant: merchant,
        amount: amount,
      ).timeout(timeout);
    } catch (_) {
      // Timeout o excepción de hardware -> fallback seguro sin propagar error
      return null;
    }
  }

  Future<GemmaClassificationResult?> _executeClassification({
    required String rawText,
    String? merchant,
    double? amount,
  }) async {
    final ready = await _client.isModelLoaded();
    if (!ready) return null;

    final prompt = buildCompactPrompt(
      rawText: rawText,
      merchant: merchant,
      amount: amount,
    );

    final rawResponse = await _client.generateResponse(prompt);
    if (rawResponse == null || rawResponse.trim().isEmpty) return null;

    return parseGemmaResponse(rawResponse);
  }

  /// Construye un prompt compacto y sin datos sensibles innecesarios.
  static String buildCompactPrompt({
    required String rawText,
    String? merchant,
    double? amount,
  }) {
    final sanitizedContext = merchant ?? rawText;
    final amountLine = amount != null ? 'Monto: $amount\n' : '';
    return 'Clasifica esta notificacion bancaria en: "gasto", "ingreso" o "transferencia-propia".\n'
        'Detalle: $sanitizedContext\n'
        '$amountLine'
        'Responde SOLO un objeto JSON con este formato exacto:\n'
        '{"classification": "gasto|ingreso|transferencia-propia", "category": "Alimentacion", "confidence": 0.85}';
  }

  /// Parsea y valida el payload JSON emitido por Gemma.
  static GemmaClassificationResult? parseGemmaResponse(String text) {
    try {
      var cleaned = text.trim();

      // Extraer bloque JSON si viene encerrado en bloques markdown
      final jsonBlockMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (jsonBlockMatch != null) {
        cleaned = jsonBlockMatch.group(0)!;
      }

      final dynamic decoded = jsonDecode(cleaned);
      if (decoded is! Map) return null;

      final dynamic rawClassification = decoded['classification'];
      if (rawClassification is! String) return null;

      final normClassification = rawClassification.trim().toLowerCase();
      const validClassifications = {'gasto', 'ingreso', 'transferencia-propia'};
      if (!validClassifications.contains(normClassification)) {
        return null;
      }

      final category = decoded['category'] as String?;
      var confidence = (decoded['confidence'] as num?)?.toDouble() ?? 0.82;
      if (confidence < 0.0) confidence = 0.0;
      if (confidence > 1.0) confidence = 1.0;

      return GemmaClassificationResult(
        classification: normClassification,
        category: category,
        confidence: confidence,
      );
    } catch (_) {
      return null;
    }
  }
}
