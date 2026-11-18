import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';

/// Identificadores de proveedores/motores de IA soportados como IA Principal.
enum AiProviderId {
  localGemmaDefault('local_gemma_default'),
  localHuggingFace('local_huggingface'),
  openRouter('openrouter'),
  nvidiaNim('nvidia_nim'),
  openCodeZen('opencode_zen'),
  gemini('gemini'),
  openAi('openai'),
  simulator('simulator');

  final String wireValue;
  const AiProviderId(this.wireValue);

  bool get isCloud =>
      this == openRouter ||
      this == nvidiaNim ||
      this == openCodeZen ||
      this == gemini ||
      this == openAi;

  bool get isLocalGemma =>
      this == localGemmaDefault || this == localHuggingFace;

  bool get supportsAutoFreeQueue =>
      this == openRouter || this == nvidiaNim || this == openCodeZen;

  String get displayName {
    switch (this) {
      case AiProviderId.localGemmaDefault:
        return 'Gemma 4 E2B (Local)';
      case AiProviderId.localHuggingFace:
        return 'HuggingFace (.litertlm)';
      case AiProviderId.openRouter:
        return 'OpenRouter';
      case AiProviderId.nvidiaNim:
        return 'NVIDIA NIM (build.nvidia.com)';
      case AiProviderId.openCodeZen:
        return 'OpenCode Zen';
      case AiProviderId.gemini:
        return 'Google Gemini';
      case AiProviderId.openAi:
        return 'OpenAI (GPT)';
      case AiProviderId.simulator:
        return 'Simulador Local (Sin IA)';
    }
  }

  String? get defaultBaseUrl {
    switch (this) {
      case AiProviderId.openRouter:
        return 'https://openrouter.ai/api/v1';
      case AiProviderId.nvidiaNim:
        return 'https://integrate.api.nvidia.com/v1';
      case AiProviderId.openCodeZen:
        return 'https://opencode.ai/zen/v1';
      case AiProviderId.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta/openai';
      case AiProviderId.openAi:
        return 'https://api.openai.com/v1';
      case AiProviderId.localGemmaDefault:
      case AiProviderId.localHuggingFace:
      case AiProviderId.simulator:
        return null;
    }
  }

  /// Lista curada por defecto de modelos (priorizando gratuitos en proveedores free-tier).
  List<String> get defaultFreeOrRecommendedModels {
    switch (this) {
      case AiProviderId.openRouter:
        return const [
          'openrouter/free',
          'google/gemma-3-27b-it:free',
          'meta-llama/llama-3.3-70b-instruct:free',
          'deepseek/deepseek-r1:free',
        ];
      case AiProviderId.nvidiaNim:
        return const [
          'meta/llama-3.3-70b-instruct',
          'nvidia/llama-3.1-nemotron-ultra-253b-v1',
          'google/gemma-3-27b-it',
          'meta/llama-3.1-8b-instruct',
        ];
      case AiProviderId.openCodeZen:
        return const [
          'deepseek-v4-flash-free',
          'qwen3.6-plus-free',
          'nemotron-3-ultra-free',
          'minimax-m3-free',
          'mimo-v2.5-free',
        ];
      case AiProviderId.gemini:
        return const [
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
        ];
      case AiProviderId.openAi:
        return const [
          'gpt-4o-mini',
          'gpt-4.1-mini',
        ];
      case AiProviderId.localGemmaDefault:
        return const ['gemma-4-E2B-it.litertlm'];
      case AiProviderId.localHuggingFace:
        return const [];
      case AiProviderId.simulator:
        return const [];
    }
  }

  static AiProviderId fromWire(String? value) {
    for (final item in AiProviderId.values) {
      if (item.wireValue == value) return item;
    }
    return AiProviderId.simulator;
  }
}

/// Metadatos no sensibles de una API Key registrada por el usuario.
///
/// El secreto real se almacena exclusivamente en [SecureKeyStore] (`FlutterSecureStorage`)
/// bajo la clave `ai_provider_secret_<id>`.
class AiApiKeyEntry {
  final String id;
  final AiProviderId provider;
  final String label;
  final String maskedKey;
  final String? preferredModel;
  final bool isEnabled;
  final DateTime createdAt;

  const AiApiKeyEntry({
    required this.id,
    required this.provider,
    required this.label,
    required this.maskedKey,
    this.preferredModel,
    this.isEnabled = true,
    required this.createdAt,
  });

  AiApiKeyEntry copyWith({
    String? id,
    AiProviderId? provider,
    String? label,
    String? maskedKey,
    String? preferredModel,
    bool clearPreferredModel = false,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return AiApiKeyEntry(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      label: label ?? this.label,
      maskedKey: maskedKey ?? this.maskedKey,
      preferredModel:
          clearPreferredModel ? null : (preferredModel ?? this.preferredModel),
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.wireValue,
        'label': label,
        'masked_key': maskedKey,
        'preferred_model': preferredModel,
        'is_enabled': isEnabled,
        'created_at': createdAt.toIso8601String(),
      };

  factory AiApiKeyEntry.fromJson(Map<String, dynamic> json) {
    return AiApiKeyEntry(
      id: json['id'] as String,
      provider: AiProviderId.fromWire(json['provider'] as String?),
      label: (json['label'] as String?) ?? 'API Key',
      maskedKey: (json['masked_key'] ?? json['maskedKey'] ?? '****') as String,
      preferredModel:
          (json['preferred_model'] ?? json['preferredModel']) as String?,
      isEnabled: (json['is_enabled'] ?? json['isEnabled']) as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  static String maskSecret(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.length <= 8) return '****';
    return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 4)}';
  }
}

/// Configuración global del motor único de IA activo para Notificaciones,
/// Reportes y Chat en Moneo.
class AiEngineConfig {
  final AiProviderId primaryProvider;
  final String? primaryKeyId;
  final bool autoRotateFreeModels;
  final bool crossProviderFallback;
  final String? localHuggingFaceUrl;
  final List<AiApiKeyEntry> apiKeys;

  const AiEngineConfig({
    this.primaryProvider = AiProviderId.simulator,
    this.primaryKeyId,
    this.autoRotateFreeModels = true,
    this.crossProviderFallback = false,
    this.localHuggingFaceUrl,
    this.apiKeys = const [],
  });

  List<AiApiKeyEntry> keysFor(AiProviderId provider) =>
      apiKeys.where((k) => k.provider == provider).toList(growable: false);

  List<AiApiKeyEntry> enabledKeysFor(AiProviderId provider) => apiKeys
      .where((k) => k.provider == provider && k.isEnabled)
      .toList(growable: false);

  AiApiKeyEntry? get activePrimaryKey {
    if (!primaryProvider.isCloud) return null;
    final candidates = enabledKeysFor(primaryProvider);
    if (candidates.isEmpty) return null;
    if (primaryKeyId != null) {
      for (final item in candidates) {
        if (item.id == primaryKeyId) return item;
      }
    }
    return candidates.first;
  }

  AiEngineConfig copyWith({
    AiProviderId? primaryProvider,
    String? primaryKeyId,
    bool clearPrimaryKeyId = false,
    bool? autoRotateFreeModels,
    bool? crossProviderFallback,
    String? localHuggingFaceUrl,
    bool clearLocalHuggingFaceUrl = false,
    List<AiApiKeyEntry>? apiKeys,
  }) {
    return AiEngineConfig(
      primaryProvider: primaryProvider ?? this.primaryProvider,
      primaryKeyId:
          clearPrimaryKeyId ? null : (primaryKeyId ?? this.primaryKeyId),
      autoRotateFreeModels: autoRotateFreeModels ?? this.autoRotateFreeModels,
      crossProviderFallback:
          crossProviderFallback ?? this.crossProviderFallback,
      localHuggingFaceUrl: clearLocalHuggingFaceUrl
          ? null
          : (localHuggingFaceUrl ?? this.localHuggingFaceUrl),
      apiKeys: apiKeys ?? this.apiKeys,
    );
  }

  Map<String, dynamic> toJson() => {
        'primary_provider': primaryProvider.wireValue,
        'primary_key_id': primaryKeyId,
        'auto_rotate_free_models': autoRotateFreeModels,
        'cross_provider_fallback': crossProviderFallback,
        'local_huggingface_url': localHuggingFaceUrl,
        'api_keys': apiKeys.map((k) => k.toJson()).toList(),
      };

  factory AiEngineConfig.fromJson(Map<String, dynamic> json) {
    final rawKeys = json['api_keys'] ?? json['apiKeys'];
    final parsedKeys = <AiApiKeyEntry>[];
    if (rawKeys is List) {
      for (final entry in rawKeys) {
        if (entry is Map) {
          try {
            parsedKeys
                .add(AiApiKeyEntry.fromJson(Map<String, dynamic>.from(entry)));
          } catch (_) {}
        }
      }
    }
    return AiEngineConfig(
      primaryProvider: AiProviderId.fromWire(
          (json['primary_provider'] ?? json['primaryProvider']) as String?),
      primaryKeyId:
          (json['primary_key_id'] ?? json['primaryKeyId']) as String?,
      autoRotateFreeModels: (json['auto_rotate_free_models'] ??
          json['autoRotateFreeModels']) as bool? ??
          true,
      crossProviderFallback: (json['cross_provider_fallback'] ??
          json['crossProviderFallback']) as bool? ??
          false,
      localHuggingFaceUrl: (json['local_huggingface_url'] ??
          json['localHuggingFaceUrl']) as String?,
      apiKeys: List<AiApiKeyEntry>.unmodifiable(parsedKeys),
    );
  }
}

/// Resultado de probar conectividad o consultar catálogo de modelos en un proveedor.
class AiProviderProbeResult {
  final bool ok;
  final String message;
  final String? activeModel;
  final List<String> discoveredModels;

  const AiProviderProbeResult({
    required this.ok,
    required this.message,
    this.activeModel,
    this.discoveredModels = const [],
  });
}

/// Almacén centralizado de configuración multi-IA y secretos en `FlutterSecureStorage`.
///
/// Mantiene compatibilidad hacia atrás con las claves legadas de `SharedPreferences`
/// (`ai_use_local_simulator` y `ai_model_url`) y expone hooks opcionales para que el
/// router de red (`AiProviderRouter`) pruebe conexiones y descubra modelos sin crear
/// dependencias circulares con la UI.
class AiProviderConfigStore extends ChangeNotifier {
  static const String configPrefsKey = 'ai_engine_config_v1';
  static const String legacySimulatorPrefsKey = 'ai_use_local_simulator';
  static const String legacyModelUrlPrefsKey = 'ai_model_url';
  static const String secretKeyPrefix = 'ai_provider_secret_';
  static const String defaultGemmaUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static final AiProviderConfigStore instance = AiProviderConfigStore();

  /// Hook inyectado por `AiProviderRouter` para probar la conexión real de una API Key.
  static Future<AiProviderProbeResult> Function(
    AiProviderId provider, {
    String? keyId,
  })? connectionTester;

  /// Hook inyectado por `AiProviderRouter` para refrescar modelos gratuitos disponibles.
  static Future<List<String>> Function(
    AiProviderId provider, {
    String? keyId,
    bool forceRefresh,
  })? modelsRefresher;

  final SecureKeyStore _keyStore;
  final Future<SharedPreferences> Function() _prefsLoader;
  AiEngineConfig _current = const AiEngineConfig();
  bool _loaded = false;
  int _revision = 0;

  AiProviderConfigStore({
    SecureKeyStore? keyStore,
    Future<SharedPreferences> Function()? prefsLoader,
  })  : _keyStore = keyStore ?? const FlutterSecureKeyStore(),
        _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  AiEngineConfig get current => _current;
  bool get isLoaded => _loaded;
  int get revision => _revision;

  Future<AiEngineConfig> loadConfig({bool forceReload = false}) async {
    if (_loaded && !forceReload) return _current;

    final prefs = await _prefsLoader();
    final rawConfig = prefs.getString(configPrefsKey);
    if (rawConfig != null && rawConfig.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawConfig);
        if (decoded is Map) {
          _current = AiEngineConfig.fromJson(Map<String, dynamic>.from(decoded));
          _loaded = true;
          return _current;
        }
      } catch (_) {}
    }

    // Migración transparente desde preferencias legadas
    final useSimulator = prefs.getBool(legacySimulatorPrefsKey);
    final legacyUrl = prefs.getString(legacyModelUrlPrefsKey)?.trim();
    final AiProviderId migratedProvider;
    if (useSimulator == false) {
      if (legacyUrl != null &&
          legacyUrl.isNotEmpty &&
          legacyUrl != defaultGemmaUrl) {
        migratedProvider = AiProviderId.localHuggingFace;
      } else {
        migratedProvider = AiProviderId.localGemmaDefault;
      }
    } else {
      migratedProvider = AiProviderId.simulator;
    }

    _current = AiEngineConfig(
      primaryProvider: migratedProvider,
      localHuggingFaceUrl:
          (legacyUrl != null && legacyUrl != defaultGemmaUrl) ? legacyUrl : null,
    );
    _loaded = true;
    return _current;
  }

  Future<void> saveConfig(AiEngineConfig config) async {
    final prefs = await _prefsLoader();
    _current = config;
    _loaded = true;
    _revision++;

    await prefs.setString(configPrefsKey, jsonEncode(config.toJson()));

    // Sincronizar claves legadas para retrocompatibilidad con AiChatService y main.dart
    await prefs.setBool(
      legacySimulatorPrefsKey,
      config.primaryProvider == AiProviderId.simulator,
    );
    if (config.primaryProvider == AiProviderId.localGemmaDefault) {
      await prefs.setString(legacyModelUrlPrefsKey, defaultGemmaUrl);
    } else if (config.primaryProvider == AiProviderId.localHuggingFace &&
        config.localHuggingFaceUrl != null &&
        config.localHuggingFaceUrl!.trim().isNotEmpty) {
      await prefs.setString(
        legacyModelUrlPrefsKey,
        config.localHuggingFaceUrl!.trim(),
      );
    }

    notifyListeners();
  }

  Future<AiApiKeyEntry> addApiKey({
    required AiProviderId provider,
    required String label,
    required String rawApiKey,
    String? preferredModel,
    bool setAsPrimary = false,
  }) async {
    if (!provider.isCloud) {
      throw ArgumentError('Solo los proveedores Cloud aceptan API Keys.');
    }
    final cleanKey = rawApiKey.trim();
    if (cleanKey.isEmpty) {
      throw ArgumentError('La API Key no puede estar vacía.');
    }

    final cfg = await loadConfig();
    final id = 'key_${provider.wireValue}_${DateTime.now().microsecondsSinceEpoch}';
    await _keyStore.write('$secretKeyPrefix$id', cleanKey);

    final entry = AiApiKeyEntry(
      id: id,
      provider: provider,
      label: label.trim().isEmpty ? provider.displayName : label.trim(),
      maskedKey: AiApiKeyEntry.maskSecret(cleanKey),
      preferredModel:
          (preferredModel != null && preferredModel.trim().isNotEmpty)
              ? preferredModel.trim()
              : null,
      isEnabled: true,
      createdAt: DateTime.now(),
    );

    final nextKeys = [...cfg.apiKeys, entry];
    final nextConfig = cfg.copyWith(
      apiKeys: nextKeys,
      primaryProvider: setAsPrimary ? provider : cfg.primaryProvider,
      primaryKeyId: setAsPrimary ? id : cfg.primaryKeyId,
    );
    await saveConfig(nextConfig);
    return entry;
  }

  Future<void> updateApiKey(AiApiKeyEntry updated) async {
    final cfg = await loadConfig();
    final nextKeys = cfg.apiKeys
        .map((k) => k.id == updated.id ? updated : k)
        .toList(growable: false);
    await saveConfig(cfg.copyWith(apiKeys: nextKeys));
  }

  Future<void> removeApiKey(String keyId) async {
    final cfg = await loadConfig();
    await _keyStore.delete('$secretKeyPrefix$keyId');
    final nextKeys = cfg.apiKeys.where((k) => k.id != keyId).toList();
    final clearedPrimary = cfg.primaryKeyId == keyId;
    var nextProvider = cfg.primaryProvider;
    String? nextPrimaryKeyId = clearedPrimary ? null : cfg.primaryKeyId;

    if (clearedPrimary && nextProvider.isCloud) {
      final remainingForProvider =
          nextKeys.where((k) => k.provider == nextProvider && k.isEnabled);
      if (remainingForProvider.isNotEmpty) {
        nextPrimaryKeyId = remainingForProvider.first.id;
      } else {
        nextProvider = AiProviderId.simulator;
      }
    }

    await saveConfig(
      cfg.copyWith(
        apiKeys: nextKeys,
        primaryProvider: nextProvider,
        primaryKeyId: nextPrimaryKeyId,
        clearPrimaryKeyId: nextPrimaryKeyId == null,
      ),
    );
  }

  Future<void> setPrimaryProvider(
    AiProviderId provider, {
    String? keyId,
    String? huggingFaceUrl,
  }) async {
    final cfg = await loadConfig();
    String? resolvedKeyId = keyId;
    if (provider.isCloud && resolvedKeyId == null) {
      final enabled = cfg.enabledKeysFor(provider);
      if (enabled.isNotEmpty) {
        resolvedKeyId = enabled.first.id;
      }
    }

    await saveConfig(
      cfg.copyWith(
        primaryProvider: provider,
        primaryKeyId: provider.isCloud ? resolvedKeyId : null,
        clearPrimaryKeyId: !provider.isCloud || resolvedKeyId == null,
        localHuggingFaceUrl: huggingFaceUrl ?? cfg.localHuggingFaceUrl,
      ),
    );
  }

  Future<String?> readRawApiKey(String keyId) =>
      _keyStore.read('$secretKeyPrefix$keyId');

  Future<AiProviderProbeResult> testConnection(
    AiProviderId provider, {
    String? keyId,
  }) async {
    final tester = connectionTester;
    if (tester != null) {
      return tester(provider, keyId: keyId);
    }
    return AiProviderProbeResult(
      ok: true,
      message: 'Configuración guardada para ${provider.displayName}.',
      discoveredModels: provider.defaultFreeOrRecommendedModels,
    );
  }

  Future<List<String>> fetchAvailableModels(
    AiProviderId provider, {
    String? keyId,
    bool forceRefresh = false,
  }) async {
    final refresher = modelsRefresher;
    if (refresher != null) {
      return refresher(
        provider,
        keyId: keyId,
        forceRefresh: forceRefresh,
      );
    }
    return provider.defaultFreeOrRecommendedModels;
  }
}
