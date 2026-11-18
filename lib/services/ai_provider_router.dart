import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/core/utils/app_logger.dart';
import 'package:finazaap/services/ai_provider_config.dart';

/// Mensaje de conversación compatible con endpoints OpenAI Chat Completions.
class AiRouterMessage {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;

  const AiRouterMessage({
    required this.role,
    required this.content,
  });

  Map<String, String> toJson() => {
        'role': role,
        'content': content,
      };
}

/// Respuesta consolidada de una invocación exitosa a [AiProviderRouter].
class AiRouterResponse {
  final String text;
  final AiProviderId provider;
  final String model;
  final String keyId;
  final int attempts;
  final bool usedFallbackProvider;

  const AiRouterResponse({
    required this.text,
    required this.provider,
    required this.model,
    required this.keyId,
    required this.attempts,
    this.usedFallbackProvider = false,
  });
}

/// Fragmento de streaming SSE emitido por [AiProviderRouter.streamChat].
class AiRouterStreamChunk {
  final String delta;
  final AiProviderId provider;
  final String model;
  final String keyId;
  final bool usedFallbackProvider;

  const AiRouterStreamChunk({
    required this.delta,
    required this.provider,
    required this.model,
    required this.keyId,
    this.usedFallbackProvider = false,
  });
}

/// Error estructurado del router cuando todos los modelos, llaves y proveedores elegibles fallan.
class AiRouterException implements Exception {
  final String message;
  final int? statusCode;
  final AiProviderId? provider;

  const AiRouterException(
    this.message, {
    this.statusCode,
    this.provider,
  });

  @override
  String toString() => 'AiRouterException($message)';
}

class _ModelProbeOutcome {
  final List<String>? models;
  final int? statusCode;
  final String? errorMessage;

  const _ModelProbeOutcome({
    this.models,
    this.statusCode,
    this.errorMessage,
  });
}

/// Router HTTP unificado Multi-Proveedor y Multi-API Key para Moneo.
///
/// Soporta esquemas OpenAI-compatible para OpenRouter, NVIDIA NIM, OpenCode Zen,
/// Google Gemini y OpenAI, con:
/// - Cola server-side en OpenRouter (`models` + `openrouter/free` + `allow_fallbacks`)
/// - Cola y mapa de cooldown en cliente (`_cooldownUntil`) para 429 (`Retry-After`),
///   402, 503 y 404 en NVIDIA NIM, OpenCode Zen y demás proveedores
/// - Rotación entre múltiples API Keys habilitadas del mismo proveedor
/// - Respaldo cruzado entre proveedores Cloud cuando `crossProviderFallback == true`
/// - Descubrimiento `/models` cacheado 24 horas en `SharedPreferences`
class AiProviderRouter {
  static const Duration modelsCacheTtl = Duration(hours: 24);
  static const Duration defaultCooldown = Duration(seconds: 60);
  static const Duration defaultRequestTimeout = Duration(seconds: 25);
  static const Duration authCooldown = Duration(minutes: 10);
  static const Duration notFoundCooldown = Duration(minutes: 30);
  static const String modelsCacheKeyPrefix = 'ai_provider_models_cache_';

  static final AiProviderRouter instance = AiProviderRouter();

  final http.Client _httpClient;
  final AiProviderConfigStore _configStore;
  final Future<SharedPreferences> Function() _prefsLoader;
  final DateTime Function() _now;

  /// Mapa de enfriamiento por modelo/llave tras recibir HTTP 429/402/503/404/401.
  final Map<String, DateTime> _cooldownUntil = <String, DateTime>{};

  AiProviderRouter({
    http.Client? httpClient,
    AiProviderConfigStore? configStore,
    Future<SharedPreferences> Function()? prefsLoader,
    DateTime Function()? nowProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _configStore = configStore ?? AiProviderConfigStore.instance,
        _prefsLoader = prefsLoader ?? SharedPreferences.getInstance,
        _now = nowProvider ?? DateTime.now;

  /// Registra los hooks globales en [AiProviderConfigStore] para pruebas de conexión y catálogo.
  static void registerHooks({AiProviderRouter? router}) {
    final target = router ?? instance;
    AiProviderConfigStore.connectionTester = target.testConnection;
    AiProviderConfigStore.modelsRefresher = target.fetchAvailableModels;
  }

  /// Registra los hooks únicamente si no han sido asignados todavía.
  static void ensureHooksRegistered({AiProviderRouter? router}) {
    final target = router ?? instance;
    AiProviderConfigStore.connectionTester ??= target.testConnection;
    AiProviderConfigStore.modelsRefresher ??= target.fetchAvailableModels;
  }

  /// Vincula esta instancia a los hooks estáticos de [AiProviderConfigStore].
  void bindConfigStoreHooks() => registerHooks(router: this);

  @visibleForTesting
  Map<String, DateTime> get cooldownUntil => Map.unmodifiable(_cooldownUntil);

  @visibleForTesting
  void clearCooldowns() => _cooldownUntil.clear();

  /// Verifica si una tupla proveedor/llave/modelo está en cooldown activo.
  bool isModelInCooldown(
    AiProviderId provider,
    String model, {
    String? keyId,
  }) {
    final now = _now();
    if (_isEntryActive(_globalModelCooldownKey(provider, model), now)) {
      return true;
    }
    if (keyId != null) {
      if (_isEntryActive(_apiKeyCooldownKey(provider, keyId), now) ||
          _isEntryActive(_modelKeyCooldownKey(provider, keyId, model), now)) {
        return true;
      }
    }
    return false;
  }

  /// Ejecuta una petición de completado (no streaming) con rotación de modelos, llaves y proveedores.
  Future<AiRouterResponse> completeChat({
    required List<AiRouterMessage> messages,
    String? systemPrompt,
    AiEngineConfig? configOverride,
    AiProviderId? providerOverride,
    String? keyIdOverride,
    String? modelOverride,
    int? maxTokens,
    double? temperature,
    Duration timeout = defaultRequestTimeout,
  }) async {
    final cfg = configOverride ?? await _configStore.loadConfig();
    final providers = _buildProviderQueue(
      cfg,
      providerOverride: providerOverride,
    );

    if (providers.isEmpty) {
      throw const AiRouterException(
        'No hay proveedor Cloud habilitado para ejecutar la consulta.',
      );
    }

    int attempts = 0;
    int? lastStatus;
    AiProviderId? lastProvider;
    String lastError = 'Sin proveedores o API Keys disponibles.';

    for (var pIdx = 0; pIdx < providers.length; pIdx++) {
      final provider = providers[pIdx];
      final keys = _buildKeyQueue(
        cfg,
        provider,
        preferredKeyId: pIdx == 0 ? keyIdOverride : null,
      );
      if (keys.isEmpty) {
        lastError = 'No hay API Keys activas para ${provider.displayName}.';
        continue;
      }

      for (final keyEntry in keys) {
        if (_isKeyInCooldown(provider, keyEntry.id)) {
          continue;
        }
        final rawKey = await _configStore.readRawApiKey(keyEntry.id);
        if (rawKey == null || rawKey.trim().isEmpty) {
          lastError = 'API Key "${keyEntry.label}" sin secreto disponible.';
          continue;
        }

        final candidateModels = await _resolveCandidateModels(
          cfg,
          provider,
          keyEntry,
          modelOverride: pIdx == 0 ? modelOverride : null,
        );
        final useOpenRouterQueue = _shouldUseOpenRouterQueue(
          cfg,
          provider,
          keyEntry,
          modelOverride: pIdx == 0 ? modelOverride : null,
        );

        if (useOpenRouterQueue) {
          final openRouterQueue = _buildOpenRouterModelsQueue(
            candidateModels,
            preferredModel: (pIdx == 0 ? modelOverride : null) ??
                keyEntry.preferredModel,
          );
          final primaryMarker = openRouterQueue.first;
          if (_isModelInCooldownInternal(provider, keyEntry.id, primaryMarker)) {
            continue;
          }

          attempts++;
          lastProvider = provider;
          try {
            final result = await _sendCompletionRequest(
              provider: provider,
              keyEntry: keyEntry,
              rawApiKey: rawKey.trim(),
              model: primaryMarker,
              openRouterModels: openRouterQueue,
              messages: messages,
              systemPrompt: systemPrompt,
              maxTokens: maxTokens,
              temperature: temperature,
              timeout: timeout,
              attempts: attempts,
              usedFallbackProvider: pIdx > 0,
            );
            return result;
          } on _RetryableHttpFailure catch (err) {
            lastStatus = err.statusCode;
            lastError = err.message;
            _recordHttpFailureCooldown(
              provider: provider,
              keyId: keyEntry.id,
              model: primaryMarker,
              statusCode: err.statusCode,
              headers: err.headers,
            );
            // OpenRouter ya evaluó su cola de modelos en el servidor; pasar a la siguiente API Key
            continue;
          } on TimeoutException {
            lastError = 'Tiempo de espera agotado en ${provider.displayName}.';
            _markModelCooldown(
              provider,
              keyEntry.id,
              primaryMarker,
              const Duration(seconds: 20),
            );
            continue;
          } catch (e) {
            lastError = 'Error de red en ${provider.displayName}: $e';
            continue;
          }
        }

        for (final model in candidateModels) {
          if (_isModelInCooldownInternal(provider, keyEntry.id, model)) {
            continue;
          }

          attempts++;
          lastProvider = provider;
          try {
            final result = await _sendCompletionRequest(
              provider: provider,
              keyEntry: keyEntry,
              rawApiKey: rawKey.trim(),
              model: model,
              openRouterModels: null,
              messages: messages,
              systemPrompt: systemPrompt,
              maxTokens: maxTokens,
              temperature: temperature,
              timeout: timeout,
              attempts: attempts,
              usedFallbackProvider: pIdx > 0,
            );
            return result;
          } on _RetryableHttpFailure catch (err) {
            lastStatus = err.statusCode;
            lastError = err.message;
            _recordHttpFailureCooldown(
              provider: provider,
              keyId: keyEntry.id,
              model: model,
              statusCode: err.statusCode,
              headers: err.headers,
            );
            if (err.statusCode == 401 || err.statusCode == 403) {
              // Llave inválida o sin permisos: saltar a la siguiente API Key
              break;
            }
          } on TimeoutException {
            lastError = 'Tiempo de espera agotado en ${provider.displayName} ($model).';
            _markModelCooldown(
              provider,
              keyEntry.id,
              model,
              const Duration(seconds: 20),
            );
          } catch (e) {
            lastError = 'Error de conexión con ${provider.displayName}: $e';
          }
        }
      }
    }

    throw AiRouterException(
      lastError,
      statusCode: lastStatus,
      provider: lastProvider,
    );
  }

  /// Ejecuta chat con soporte de streaming SSE y fallback transparente a JSON plano o rotación.
  Stream<AiRouterStreamChunk> streamChat({
    required List<AiRouterMessage> messages,
    String? systemPrompt,
    AiEngineConfig? configOverride,
    AiProviderId? providerOverride,
    String? keyIdOverride,
    String? modelOverride,
    int? maxTokens,
    double? temperature,
    Duration timeout = defaultRequestTimeout,
  }) async* {
    final cfg = configOverride ?? await _configStore.loadConfig();
    final providers = _buildProviderQueue(
      cfg,
      providerOverride: providerOverride,
    );

    if (providers.isEmpty) {
      throw const AiRouterException(
        'No hay proveedor Cloud habilitado para iniciar el chat.',
      );
    }

    int? lastStatus;
    AiProviderId? lastProvider;
    String lastError = 'Sin proveedores o API Keys disponibles.';

    for (var pIdx = 0; pIdx < providers.length; pIdx++) {
      final provider = providers[pIdx];
      final keys = _buildKeyQueue(
        cfg,
        provider,
        preferredKeyId: pIdx == 0 ? keyIdOverride : null,
      );
      if (keys.isEmpty) {
        lastError = 'No hay API Keys activas para ${provider.displayName}.';
        continue;
      }

      for (final keyEntry in keys) {
        if (_isKeyInCooldown(provider, keyEntry.id)) {
          continue;
        }
        final rawKey = await _configStore.readRawApiKey(keyEntry.id);
        if (rawKey == null || rawKey.trim().isEmpty) {
          lastError = 'API Key "${keyEntry.label}" sin secreto disponible.';
          continue;
        }

        final candidateModels = await _resolveCandidateModels(
          cfg,
          provider,
          keyEntry,
          modelOverride: pIdx == 0 ? modelOverride : null,
        );
        final useOpenRouterQueue = _shouldUseOpenRouterQueue(
          cfg,
          provider,
          keyEntry,
          modelOverride: pIdx == 0 ? modelOverride : null,
        );

        final modelsToTry = useOpenRouterQueue
            ? [
                _buildOpenRouterModelsQueue(
                  candidateModels,
                  preferredModel: (pIdx == 0 ? modelOverride : null) ??
                      keyEntry.preferredModel,
                ).first,
              ]
            : candidateModels;

        final openRouterQueue = useOpenRouterQueue
            ? _buildOpenRouterModelsQueue(
                candidateModels,
                preferredModel: (pIdx == 0 ? modelOverride : null) ??
                    keyEntry.preferredModel,
              )
            : null;

        for (final model in modelsToTry) {
          if (_isModelInCooldownInternal(provider, keyEntry.id, model)) {
            continue;
          }

          lastProvider = provider;
          var emittedAnyToken = false;

          try {
            final chunkStream = _sendStreamingRequest(
              provider: provider,
              keyEntry: keyEntry,
              rawApiKey: rawKey.trim(),
              model: model,
              openRouterModels: openRouterQueue,
              messages: messages,
              systemPrompt: systemPrompt,
              maxTokens: maxTokens,
              temperature: temperature,
              timeout: timeout,
              usedFallbackProvider: pIdx > 0,
            );

            await for (final chunk in chunkStream) {
              emittedAnyToken = true;
              yield chunk;
            }
            if (emittedAnyToken) {
              return;
            }
            // Respuesta vacía sin error HTTP: intentar siguiente candidato
            lastError = 'Respuesta vacía desde ${provider.displayName} ($model).';
          } on _RetryableHttpFailure catch (err) {
            if (emittedAnyToken) return;
            lastStatus = err.statusCode;
            lastError = err.message;
            _recordHttpFailureCooldown(
              provider: provider,
              keyId: keyEntry.id,
              model: model,
              statusCode: err.statusCode,
              headers: err.headers,
            );
            if (err.statusCode == 401 || err.statusCode == 403) {
              break;
            }
          } on TimeoutException {
            if (emittedAnyToken) return;
            lastError = 'Tiempo de espera agotado en ${provider.displayName} ($model).';
            _markModelCooldown(
              provider,
              keyEntry.id,
              model,
              const Duration(seconds: 20),
            );
          } catch (e) {
            if (emittedAnyToken) return;
            lastError = 'Error de streaming en ${provider.displayName}: $e';
          }
        }
      }
    }

    throw AiRouterException(
      lastError,
      statusCode: lastStatus,
      provider: lastProvider,
    );
  }

  /// Prueba la conexión real de un proveedor / API Key y devuelve el modelo activo y catálogo descubierto.
  Future<AiProviderProbeResult> testConnection(
    AiProviderId provider, {
    String? keyId,
  }) async {
    if (!provider.isCloud) {
      return AiProviderProbeResult(
        ok: true,
        message: 'Modo ${provider.displayName} disponible localmente.',
        discoveredModels: provider.defaultFreeOrRecommendedModels,
      );
    }

    final cfg = await _configStore.loadConfig();
    final keyEntry = _resolveTargetKeyForProbe(cfg, provider, keyId: keyId);
    if (keyEntry == null) {
      return AiProviderProbeResult(
        ok: false,
        message: 'No hay API Key configurada para ${provider.displayName}.',
        discoveredModels: provider.defaultFreeOrRecommendedModels,
      );
    }

    final rawKey = await _configStore.readRawApiKey(keyEntry.id);
    if (rawKey == null || rawKey.trim().isEmpty) {
      return AiProviderProbeResult(
        ok: false,
        message: 'La API Key "${keyEntry.label}" no tiene secreto guardado.',
        discoveredModels: provider.defaultFreeOrRecommendedModels,
      );
    }

    final probe = await _probeModelsEndpoint(
      provider: provider,
      rawApiKey: rawKey.trim(),
    );
    if (probe.statusCode == 401 || probe.statusCode == 403) {
      return AiProviderProbeResult(
        ok: false,
        message:
            'API Key rechazada por ${provider.displayName} (HTTP ${probe.statusCode}).',
        discoveredModels: provider.defaultFreeOrRecommendedModels,
      );
    }

    final discovered = probe.models != null && probe.models!.isNotEmpty
        ? probe.models!
        : await _readCachedOrDefaultModels(provider);

    if (probe.models != null && probe.models!.isNotEmpty) {
      await _writeModelsCache(provider, probe.models!);
    }

    try {
      final probeCfg = AiEngineConfig(
        primaryProvider: provider,
        primaryKeyId: keyEntry.id,
        autoRotateFreeModels: cfg.autoRotateFreeModels,
        crossProviderFallback: false,
        apiKeys: [keyEntry.copyWith(isEnabled: true)],
      );
      final completion = await completeChat(
        messages: const [
          AiRouterMessage(role: 'user', content: 'Responde OK.'),
        ],
        configOverride: probeCfg,
        providerOverride: provider,
        keyIdOverride: keyEntry.id,
        maxTokens: 12,
        temperature: 0.0,
        timeout: const Duration(seconds: 10),
      );
      return AiProviderProbeResult(
        ok: true,
        message:
            'Conexión exitosa con ${provider.displayName} (${completion.model}).',
        activeModel: completion.model,
        discoveredModels: discovered,
      );
    } on AiRouterException catch (e) {
      return AiProviderProbeResult(
        ok: false,
        message: e.statusCode == 429
            ? 'Límite temporal alcanzado en ${provider.displayName} (HTTP 429). Intenta más tarde.'
            : e.message,
        discoveredModels: discovered,
      );
    } catch (e) {
      return AiProviderProbeResult(
        ok: false,
        message: 'No se pudo completar la prueba en ${provider.displayName}: $e',
        discoveredModels: discovered,
      );
    }
  }

  /// Consulta `/models` en el proveedor y cachea el resultado 24 horas en `SharedPreferences`.
  Future<List<String>> fetchAvailableModels(
    AiProviderId provider, {
    String? keyId,
    bool forceRefresh = false,
  }) async {
    if (!provider.isCloud) {
      return provider.defaultFreeOrRecommendedModels;
    }

    if (!forceRefresh) {
      final fresh = await _readFreshModelsCache(provider);
      if (fresh != null && fresh.isNotEmpty) {
        return fresh;
      }
    }

    final cfg = await _configStore.loadConfig();
    final keyEntry = _resolveTargetKeyForProbe(cfg, provider, keyId: keyId);
    if (keyEntry == null) {
      return await _readCachedOrDefaultModels(provider);
    }

    final rawKey = await _configStore.readRawApiKey(keyEntry.id);
    if (rawKey == null || rawKey.trim().isEmpty) {
      return await _readCachedOrDefaultModels(provider);
    }

    final probe = await _probeModelsEndpoint(
      provider: provider,
      rawApiKey: rawKey.trim(),
    );
    if (probe.models != null && probe.models!.isNotEmpty) {
      await _writeModelsCache(provider, probe.models!);
      return probe.models!;
    }

    return await _readCachedOrDefaultModels(provider);
  }

  // ---------------------------------------------------------------------------
  // Ejecución HTTP
  // ---------------------------------------------------------------------------

  Future<AiRouterResponse> _sendCompletionRequest({
    required AiProviderId provider,
    required AiApiKeyEntry keyEntry,
    required String rawApiKey,
    required String model,
    required List<String>? openRouterModels,
    required List<AiRouterMessage> messages,
    required String? systemPrompt,
    required int? maxTokens,
    required double? temperature,
    required Duration timeout,
    required int attempts,
    required bool usedFallbackProvider,
  }) async {
    final baseUrl = provider.defaultBaseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw AiRouterException('Base URL no definida para ${provider.displayName}.');
    }

    final uri = Uri.parse('${_trimTrailingSlash(baseUrl)}/chat/completions');
    final payload = _buildCompletionPayload(
      provider: provider,
      model: model,
      openRouterModels: openRouterModels,
      messages: messages,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
      stream: false,
    );

    final response = await _httpClient
        .post(
          uri,
          headers: _buildHeaders(provider, rawApiKey),
          body: jsonEncode(payload),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _RetryableHttpFailure(
        statusCode: response.statusCode,
        headers: response.headers,
        message: _formatHttpError(
          provider,
          model,
          response.statusCode,
          _safeUtf8(response.bodyBytes),
        ),
      );
    }

    final rawJson = _safeUtf8(response.bodyBytes);
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Respuesta JSON inesperada en chat/completions.');
    }

    final text = _extractChoiceText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Respuesta sin contenido en choices[0].');
    }

    final respondedModel = (decoded['model'] as String?)?.trim();
    return AiRouterResponse(
      text: text,
      provider: provider,
      model: (respondedModel != null && respondedModel.isNotEmpty)
          ? respondedModel
          : model,
      keyId: keyEntry.id,
      attempts: attempts,
      usedFallbackProvider: usedFallbackProvider,
    );
  }

  Stream<AiRouterStreamChunk> _sendStreamingRequest({
    required AiProviderId provider,
    required AiApiKeyEntry keyEntry,
    required String rawApiKey,
    required String model,
    required List<String>? openRouterModels,
    required List<AiRouterMessage> messages,
    required String? systemPrompt,
    required int? maxTokens,
    required double? temperature,
    required Duration timeout,
    required bool usedFallbackProvider,
  }) async* {
    final baseUrl = provider.defaultBaseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw AiRouterException('Base URL no definida para ${provider.displayName}.');
    }

    final uri = Uri.parse('${_trimTrailingSlash(baseUrl)}/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll(_buildHeaders(provider, rawApiKey))
      ..body = jsonEncode(
        _buildCompletionPayload(
          provider: provider,
          model: model,
          openRouterModels: openRouterModels,
          messages: messages,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
          stream: true,
        ),
      );

    final streamedResponse = await _httpClient.send(request).timeout(timeout);
    if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
      final errBytes = await streamedResponse.stream.toBytes();
      throw _RetryableHttpFailure(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        message: _formatHttpError(
          provider,
          model,
          streamedResponse.statusCode,
          _safeUtf8(errBytes),
        ),
      );
    }

    final contentType =
        (_headerCaseInsensitive(streamedResponse.headers, 'content-type') ?? '')
            .toLowerCase();

    if (!contentType.contains('text/event-stream')) {
      final rawBytes = await streamedResponse.stream.toBytes();
      final bodyText = _safeUtf8(rawBytes);
      // Algunos mocks o servidores devuelven SSE sin header content-type explícito
      if (!bodyText.trimLeft().startsWith('{') &&
          bodyText.contains('data:')) {
        yield* _parseSseLines(
          LineSplitter.split(bodyText),
          provider: provider,
          fallbackModel: model,
          keyId: keyEntry.id,
          usedFallbackProvider: usedFallbackProvider,
        );
        return;
      }
      final decoded = jsonDecode(bodyText);
      if (decoded is Map) {
        final content = _extractChoiceText(decoded);
        if (content != null && content.isNotEmpty) {
          final respondedModel = (decoded['model'] as String?)?.trim();
          yield AiRouterStreamChunk(
            delta: content,
            provider: provider,
            model: (respondedModel != null && respondedModel.isNotEmpty)
                ? respondedModel
                : model,
            keyId: keyEntry.id,
            usedFallbackProvider: usedFallbackProvider,
          );
        }
      }
      return;
    }

    var currentModel = model;
    await for (final line in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final chunk = _parseSingleSseLine(
        line,
        provider: provider,
        currentModel: currentModel,
        keyId: keyEntry.id,
        usedFallbackProvider: usedFallbackProvider,
      );
      if (chunk == null) {
        if (line.trim() == 'data: [DONE]' || line.trim() == 'data:[DONE]') {
          return;
        }
        continue;
      }
      currentModel = chunk.model;
      yield chunk;
    }
  }

  Stream<AiRouterStreamChunk> _parseSseLines(
    Iterable<String> lines, {
    required AiProviderId provider,
    required String fallbackModel,
    required String keyId,
    required bool usedFallbackProvider,
  }) async* {
    var currentModel = fallbackModel;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == 'data: [DONE]' || trimmed == 'data:[DONE]') {
        return;
      }
      final chunk = _parseSingleSseLine(
        line,
        provider: provider,
        currentModel: currentModel,
        keyId: keyId,
        usedFallbackProvider: usedFallbackProvider,
      );
      if (chunk != null) {
        currentModel = chunk.model;
        yield chunk;
      }
    }
  }

  AiRouterStreamChunk? _parseSingleSseLine(
    String line, {
    required AiProviderId provider,
    required String currentModel,
    required String keyId,
    required bool usedFallbackProvider,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(':')) return null;
    if (!trimmed.startsWith('data:')) return null;

    final dataPayload = trimmed.substring(5).trim();
    if (dataPayload.isEmpty || dataPayload == '[DONE]') return null;

    try {
      final decoded = jsonDecode(dataPayload);
      if (decoded is! Map) return null;
      final chunkModel = (decoded['model'] as String?)?.trim();
      final resolvedModel = (chunkModel != null && chunkModel.isNotEmpty)
          ? chunkModel
          : currentModel;

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final first = choices.first;
      if (first is! Map) return null;

      String? deltaText;
      final delta = first['delta'];
      if (delta is Map) {
        deltaText = _extractContentField(delta['content']);
      }
      deltaText ??= _extractContentField(
        first['message'] is Map ? (first['message'] as Map)['content'] : null,
      );

      if (deltaText == null || deltaText.isEmpty) return null;
      return AiRouterStreamChunk(
        delta: deltaText,
        provider: provider,
        model: resolvedModel,
        keyId: keyId,
        usedFallbackProvider: usedFallbackProvider,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildCompletionPayload({
    required AiProviderId provider,
    required String model,
    required List<String>? openRouterModels,
    required List<AiRouterMessage> messages,
    required String? systemPrompt,
    required int? maxTokens,
    required double? temperature,
    required bool stream,
  }) {
    final msgList = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': systemPrompt.trim()},
      for (final m in messages) m.toJson(),
    ];

    final payload = <String, dynamic>{
      'model': model,
      'messages': msgList,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      if (stream) 'stream': true,
    };

    if (provider == AiProviderId.openRouter &&
        openRouterModels != null &&
        openRouterModels.isNotEmpty) {
      payload['models'] = openRouterModels;
      payload['provider'] = const {'allow_fallbacks': true};
    }

    return payload;
  }

  Map<String, String> _buildHeaders(AiProviderId provider, String rawApiKey) {
    return <String, String>{
      'Authorization': 'Bearer $rawApiKey',
      'Content-Type': 'application/json',
      if (provider == AiProviderId.openRouter) ...{
        'HTTP-Referer': 'https://moneo.local',
        'X-Title': 'Moneo',
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Cola de proveedores, API keys y modelos
  // ---------------------------------------------------------------------------

  List<AiProviderId> _buildProviderQueue(
    AiEngineConfig cfg, {
    AiProviderId? providerOverride,
  }) {
    final primary = providerOverride ?? cfg.primaryProvider;
    if (!primary.isCloud) return const [];

    final queue = <AiProviderId>[primary];
    if (providerOverride == null && cfg.crossProviderFallback) {
      for (final candidate in AiProviderId.values) {
        if (candidate.isCloud &&
            candidate != primary &&
            cfg.enabledKeysFor(candidate).isNotEmpty) {
          queue.add(candidate);
        }
      }
    }
    return queue;
  }

  List<AiApiKeyEntry> _buildKeyQueue(
    AiEngineConfig cfg,
    AiProviderId provider, {
    String? preferredKeyId,
  }) {
    final enabled = cfg.enabledKeysFor(provider);
    if (enabled.isEmpty) return const [];

    final targetId = preferredKeyId ??
        (provider == cfg.primaryProvider ? cfg.primaryKeyId : null);
    if (targetId == null) return enabled;

    final ordered = <AiApiKeyEntry>[];
    for (final k in enabled) {
      if (k.id == targetId) ordered.add(k);
    }
    for (final k in enabled) {
      if (k.id != targetId) ordered.add(k);
    }
    return ordered;
  }

  AiApiKeyEntry? _resolveTargetKeyForProbe(
    AiEngineConfig cfg,
    AiProviderId provider, {
    String? keyId,
  }) {
    if (keyId != null) {
      for (final k in cfg.keysFor(provider)) {
        if (k.id == keyId) return k;
      }
    }
    if (cfg.primaryProvider == provider && cfg.activePrimaryKey != null) {
      return cfg.activePrimaryKey;
    }
    final enabled = cfg.enabledKeysFor(provider);
    if (enabled.isNotEmpty) return enabled.first;
    final all = cfg.keysFor(provider);
    return all.isNotEmpty ? all.first : null;
  }

  bool _shouldUseOpenRouterQueue(
    AiEngineConfig cfg,
    AiProviderId provider,
    AiApiKeyEntry keyEntry, {
    String? modelOverride,
  }) {
    if (provider != AiProviderId.openRouter || !cfg.autoRotateFreeModels) {
      return false;
    }
    final selected = (modelOverride ?? keyEntry.preferredModel)?.trim() ?? '';
    return selected.isEmpty ||
        selected == 'auto' ||
        selected == 'openrouter/free' ||
        selected.endsWith(':free');
  }

  List<String> _buildOpenRouterModelsQueue(
    List<String> candidateModels, {
    String? preferredModel,
  }) {
    final cleanPreferred = preferredModel?.trim() ?? '';
    final specificFree = <String>[];
    final seen = <String>{};

    void addIfSpecificFree(String? model) {
      final trimmed = model?.trim() ?? '';
      if (trimmed.isEmpty ||
          trimmed == 'auto' ||
          trimmed == 'openrouter/free') {
        return;
      }
      if (seen.add(trimmed)) {
        specificFree.add(trimmed);
      }
    }

    if (cleanPreferred.isNotEmpty &&
        cleanPreferred != 'auto' &&
        cleanPreferred != 'openrouter/free') {
      addIfSpecificFree(cleanPreferred);
    }

    for (final m in candidateModels) {
      if (m.endsWith(':free')) {
        addIfSpecificFree(m);
      }
    }

    for (final m in AiProviderId.openRouter.defaultFreeOrRecommendedModels) {
      if (m.endsWith(':free')) {
        addIfSpecificFree(m);
      }
    }

    // Limitar para payloads compactos preservando siempre "openrouter/free" al final
    final bounded = specificFree.take(5).toList();
    bounded.add('openrouter/free');
    return bounded;
  }

  Future<List<String>> _resolveCandidateModels(
    AiEngineConfig cfg,
    AiProviderId provider,
    AiApiKeyEntry keyEntry, {
    String? modelOverride,
  }) async {
    final preferred = (modelOverride ?? keyEntry.preferredModel)?.trim();
    final defaults = provider.defaultFreeOrRecommendedModels;

    if (!cfg.autoRotateFreeModels && provider != AiProviderId.openRouter) {
      if (preferred != null && preferred.isNotEmpty && preferred != 'auto') {
        return [preferred];
      }
      if (defaults.isNotEmpty) {
        return [defaults.first];
      }
    }

    if (provider == AiProviderId.openRouter && !cfg.autoRotateFreeModels) {
      if (preferred != null && preferred.isNotEmpty && preferred != 'auto') {
        return [preferred];
      }
      return const ['openrouter/free'];
    }

    final cached = await _readFreshModelsCache(provider);
    final merged = <String>[];
    final seen = <String>{};

    void addUnique(String? id) {
      final clean = id?.trim() ?? '';
      if (clean.isEmpty || clean == 'auto') return;
      if (seen.add(clean)) {
        merged.add(clean);
      }
    }

    addUnique(preferred);
    if (cached != null) {
      for (final m in cached) {
        addUnique(m);
      }
    }
    for (final m in defaults) {
      addUnique(m);
    }

    return merged;
  }

  // ---------------------------------------------------------------------------
  // Descubrimiento /models y caché de 24 horas
  // ---------------------------------------------------------------------------

  Future<_ModelProbeOutcome> _probeModelsEndpoint({
    required AiProviderId provider,
    required String rawApiKey,
  }) async {
    final baseUrl = provider.defaultBaseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      return _ModelProbeOutcome(models: provider.defaultFreeOrRecommendedModels);
    }

    final uri = Uri.parse('${_trimTrailingSlash(baseUrl)}/models');
    try {
      final response = await _httpClient
          .get(uri, headers: _buildHeaders(provider, rawApiKey))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _ModelProbeOutcome(
          statusCode: response.statusCode,
          errorMessage: _formatHttpError(
            provider,
            '/models',
            response.statusCode,
            _safeUtf8(response.bodyBytes),
          ),
        );
      }

      final decoded = jsonDecode(_safeUtf8(response.bodyBytes));
      final extracted = _extractModelsFromCatalog(provider, decoded);
      return _ModelProbeOutcome(
        statusCode: response.statusCode,
        models: extracted.isNotEmpty
            ? extracted
            : provider.defaultFreeOrRecommendedModels,
      );
    } catch (e) {
      AppLogger.warning(
        'No se pudo consultar /models en ${provider.displayName}: $e',
      );
      return _ModelProbeOutcome(errorMessage: e.toString());
    }
  }

  List<String> _extractModelsFromCatalog(
    AiProviderId provider,
    dynamic decoded,
  ) {
    if (decoded is! Map) return const [];
    final rawList = decoded['data'] ?? decoded['models'];
    if (rawList is! List) return const [];

    final allIds = <String>[];
    final freeIds = <String>[];
    final seen = <String>{};

    for (final item in rawList) {
      if (item is! Map) continue;
      var id = (item['id'] ?? item['name'])?.toString().trim() ?? '';
      if (id.isEmpty) continue;

      if (provider == AiProviderId.gemini && id.startsWith('models/')) {
        id = id.substring('models/'.length);
      }
      if (!seen.add(id)) continue;

      final isExplicitFree = _isCatalogEntryFree(provider, id, item);
      if (isExplicitFree) {
        freeIds.add(id);
      }
      allIds.add(id);
    }

    switch (provider) {
      case AiProviderId.openRouter:
        final ordered = freeIds
            .where((id) => id != 'openrouter/free')
            .toList(growable: true);
        if (ordered.isNotEmpty) {
          ordered.add('openrouter/free');
          return ordered;
        }
        return allIds.isNotEmpty
            ? [...allIds.take(10), 'openrouter/free']
            : provider.defaultFreeOrRecommendedModels;

      case AiProviderId.openCodeZen:
        if (freeIds.isNotEmpty) return freeIds;
        return allIds;

      case AiProviderId.nvidiaNim:
        final chatLike = allIds.where((id) {
          final lower = id.toLowerCase();
          return !lower.contains('embed') &&
              !lower.contains('rerank') &&
              !lower.contains('nvclip') &&
              !lower.contains('parse');
        }).toList();
        return chatLike.isNotEmpty ? chatLike : allIds;

      case AiProviderId.gemini:
        final geminiChat = allIds.where((id) {
          final lower = id.toLowerCase();
          return lower.contains('gemini') &&
              !lower.contains('embedding') &&
              !lower.contains('imagen') &&
              !lower.contains('veo');
        }).toList();
        return geminiChat.isNotEmpty ? geminiChat : allIds;

      case AiProviderId.openAi:
        final gptChat = allIds.where((id) {
          final lower = id.toLowerCase();
          return lower.startsWith('gpt-') ||
              lower.startsWith('o1') ||
              lower.startsWith('o3') ||
              lower.startsWith('o4');
        }).toList();
        return gptChat.isNotEmpty ? gptChat : allIds;

      case AiProviderId.localGemmaDefault:
      case AiProviderId.localHuggingFace:
      case AiProviderId.simulator:
        return provider.defaultFreeOrRecommendedModels;
    }
  }

  bool _isCatalogEntryFree(
    AiProviderId provider,
    String id,
    Map<dynamic, dynamic> item,
  ) {
    final lower = id.toLowerCase();
    if (provider == AiProviderId.openRouter) {
      if (lower == 'openrouter/free' || lower.endsWith(':free')) return true;
    } else if (provider == AiProviderId.openCodeZen) {
      if (lower.endsWith('-free') || lower.contains('free')) return true;
    }

    final pricing = item['pricing'];
    if (pricing is Map) {
      final prompt = num.tryParse('${pricing['prompt'] ?? ''}');
      final completion = num.tryParse('${pricing['completion'] ?? ''}');
      if (prompt != null &&
          completion != null &&
          prompt == 0 &&
          completion == 0) {
        return true;
      }
    }
    return item['free'] == true;
  }

  Future<List<String>?> _readFreshModelsCache(AiProviderId provider) async {
    final entry = await _readModelsCacheRaw(provider);
    if (entry == null) return null;
    if (_now().difference(entry.fetchedAt) >= modelsCacheTtl) {
      return null;
    }
    return entry.models;
  }

  Future<List<String>> _readCachedOrDefaultModels(AiProviderId provider) async {
    final entry = await _readModelsCacheRaw(provider);
    if (entry != null && entry.models.isNotEmpty) {
      return entry.models;
    }
    return provider.defaultFreeOrRecommendedModels;
  }

  Future<({DateTime fetchedAt, List<String> models})?> _readModelsCacheRaw(
    AiProviderId provider,
  ) async {
    try {
      final prefs = await _prefsLoader();
      final raw = prefs.getString('$modelsCacheKeyPrefix${provider.wireValue}');
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final fetchedStr = decoded['fetched_at'] as String?;
      final modelsRaw = decoded['models'];
      if (fetchedStr == null || modelsRaw is! List) return null;
      final fetchedAt = DateTime.tryParse(fetchedStr);
      if (fetchedAt == null) return null;
      final models = modelsRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      if (models.isEmpty) return null;
      return (fetchedAt: fetchedAt, models: models);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeModelsCache(
    AiProviderId provider,
    List<String> models,
  ) async {
    try {
      final prefs = await _prefsLoader();
      await prefs.setString(
        '$modelsCacheKeyPrefix${provider.wireValue}',
        jsonEncode({
          'fetched_at': _now().toIso8601String(),
          'models': models,
        }),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Cooldowns & parsing helpers
  // ---------------------------------------------------------------------------

  String _modelKeyCooldownKey(
    AiProviderId provider,
    String keyId,
    String model,
  ) =>
      '${provider.wireValue}::$keyId::$model';

  String _globalModelCooldownKey(AiProviderId provider, String model) =>
      '${provider.wireValue}::*::$model';

  String _apiKeyCooldownKey(AiProviderId provider, String keyId) =>
      '${provider.wireValue}::key::$keyId';

  bool _isKeyInCooldown(AiProviderId provider, String keyId) =>
      _isEntryActive(_apiKeyCooldownKey(provider, keyId), _now());

  bool _isModelInCooldownInternal(
    AiProviderId provider,
    String keyId,
    String model,
  ) {
    final now = _now();
    return _isEntryActive(_apiKeyCooldownKey(provider, keyId), now) ||
        _isEntryActive(_globalModelCooldownKey(provider, model), now) ||
        _isEntryActive(_modelKeyCooldownKey(provider, keyId, model), now);
  }

  bool _isEntryActive(String cacheKey, DateTime now) {
    final until = _cooldownUntil[cacheKey];
    if (until == null) return false;
    if (now.isBefore(until)) return true;
    _cooldownUntil.remove(cacheKey);
    return false;
  }

  void _markModelCooldown(
    AiProviderId provider,
    String keyId,
    String model,
    Duration duration,
  ) {
    _cooldownUntil[_modelKeyCooldownKey(provider, keyId, model)] =
        _now().add(duration);
  }

  void _recordHttpFailureCooldown({
    required AiProviderId provider,
    required String keyId,
    required String model,
    required int statusCode,
    required Map<String, String> headers,
  }) {
    final now = _now();
    if (statusCode == 401 || statusCode == 403) {
      _cooldownUntil[_apiKeyCooldownKey(provider, keyId)] =
          now.add(authCooldown);
      return;
    }

    if (statusCode == 404) {
      final retry = _parseRetryAfter(headers, fallback: notFoundCooldown);
      _cooldownUntil[_globalModelCooldownKey(provider, model)] = now.add(retry);
      return;
    }

    if (statusCode == 429 ||
        statusCode == 402 ||
        statusCode == 503 ||
        statusCode >= 500) {
      final retry = _parseRetryAfter(headers, fallback: defaultCooldown);
      _cooldownUntil[_modelKeyCooldownKey(provider, keyId, model)] =
          now.add(retry);
    }
  }

  Duration _parseRetryAfter(
    Map<String, String> headers, {
    Duration fallback = defaultCooldown,
  }) {
    final raw = _headerCaseInsensitive(headers, 'retry-after');
    if (raw == null || raw.trim().isEmpty) return fallback;
    final trimmed = raw.trim();

    final intSeconds = int.tryParse(trimmed);
    if (intSeconds != null) {
      if (intSeconds <= 0) return const Duration(seconds: 1);
      return Duration(seconds: intSeconds.clamp(1, 3600));
    }

    final numSeconds = double.tryParse(trimmed);
    if (numSeconds != null && numSeconds.isFinite) {
      final rounded = numSeconds.ceil();
      if (rounded <= 0) return const Duration(seconds: 1);
      return Duration(seconds: rounded.clamp(1, 3600));
    }

    final isoDate = DateTime.tryParse(trimmed);
    if (isoDate != null) {
      final diff = isoDate.difference(_now());
      if (diff.inSeconds > 0) {
        return Duration(seconds: diff.inSeconds.clamp(1, 3600));
      }
    }

    return fallback;
  }

  String? _headerCaseInsensitive(Map<String, String> headers, String name) {
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) {
        return entry.value;
      }
    }
    return null;
  }

  String? _extractChoiceText(Map<dynamic, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final message = first['message'];
    if (message is Map) {
      return _extractContentField(message['content']);
    }
    return _extractContentField(first['text']);
  }

  String? _extractContentField(dynamic raw) {
    if (raw is String) return raw;
    if (raw is List) {
      final buffer = StringBuffer();
      for (final part in raw) {
        if (part is String) {
          buffer.write(part);
        } else if (part is Map) {
          final text = part['text'] ?? part['content'];
          if (text is String) buffer.write(text);
        }
      }
      final result = buffer.toString();
      return result.isEmpty ? null : result;
    }
    return null;
  }

  String _trimTrailingSlash(String url) =>
      url.replaceAll(RegExp(r'/+$'), '');

  String _safeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  String _formatHttpError(
    AiProviderId provider,
    String target,
    int statusCode,
    String body,
  ) {
    var detail = '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final msg = (decoded['error'] as Map)['message'];
        if (msg is String && msg.trim().isNotEmpty) {
          detail = ': ${msg.trim()}';
        }
      }
    } catch (_) {}
    if (detail.length > 140) {
      detail = '${detail.substring(0, 140)}...';
    }
    return '${provider.displayName} ($target) HTTP $statusCode$detail';
  }
}

class _RetryableHttpFailure implements Exception {
  final int statusCode;
  final Map<String, String> headers;
  final String message;

  const _RetryableHttpFailure({
    required this.statusCode,
    required this.headers,
    required this.message,
  });
}
