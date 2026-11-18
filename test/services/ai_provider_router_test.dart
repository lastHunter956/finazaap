import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/features/notifications/services/gemma_classifier_adapter.dart';
import 'package:finazaap/features/notifications/services/notification_box_encryption.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:finazaap/services/ai_provider_config.dart';
import 'package:finazaap/services/ai_provider_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _NoNetworkGemmaClient implements GemmaInferenceClient {
  int calls = 0;

  @override
  Future<bool> isModelLoaded() async => true;

  @override
  Future<String?> generateResponse(String prompt) async {
    calls++;
    return '{"classification":"gasto","category":"Alimentación","confidence":0.9,"strategic_note":"Cliente inyectado"}';
  }
}

class _FakeLocalChatSession implements AiChatSessionAdapter {
  bool closed = false;
  int messageCount = 0;

  @override
  Future<void> addUserMessage(String text) async {
    messageCount++;
  }

  @override
  Stream<String> generateResponseStream() async* {
    yield 'Respuesta local lazy.';
  }

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> close() async {
    closed = true;
  }
}

http.Response _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...headers,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _InMemorySecureKeyStore keyStore;
  late AiProviderConfigStore configStore;
  late DateTime fakeNow;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    keyStore = _InMemorySecureKeyStore();
    configStore = AiProviderConfigStore(keyStore: keyStore);
    fakeNow = DateTime(2026, 11, 18, 10, 0, 0);
    AiProviderConfigStore.connectionTester = null;
    AiProviderConfigStore.modelsRefresher = null;
  });

  tearDown(() {
    AiProviderConfigStore.connectionTester = null;
    AiProviderConfigStore.modelsRefresher = null;
  });

  group('AiProviderRouter - OpenRouter', () {
    test(
        'envía lista models con preferred/free + openrouter/free y allow_fallbacks, leyendo el modelo real respondido',
        () async {
      final entry = await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR Principal',
        rawApiKey: 'sk-or-test-key-1234',
        preferredModel: 'google/gemma-3-27b-it:free',
        setAsPrimary: true,
      );

      final capturedBodies = <Map<String, dynamic>>[];
      final capturedHeaders = <Map<String, String>>[];

      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          equals('https://openrouter.ai/api/v1/chat/completions'),
        );
        capturedHeaders.add(request.headers);
        capturedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);

        return _jsonResponse({
          'id': 'gen-or-1',
          'model': 'meta-llama/llama-3.3-70b-instruct:free',
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Respuesta desde fallback OpenRouter.',
              },
            },
          ],
        });
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );

      final res = await router.completeChat(
        systemPrompt: 'Asesor financiero',
        messages: const [AiRouterMessage(role: 'user', content: 'Hola')],
      );

      expect(res.provider, equals(AiProviderId.openRouter));
      expect(res.model, equals('meta-llama/llama-3.3-70b-instruct:free'));
      expect(res.keyId, equals(entry.id));
      expect(res.text, equals('Respuesta desde fallback OpenRouter.'));

      expect(
        capturedHeaders.single['Authorization'],
        equals('Bearer sk-or-test-key-1234'),
      );
      final body = capturedBodies.single;
      final sentModels = List<String>.from(body['models'] as List);
      expect(sentModels.first, equals('google/gemma-3-27b-it:free'));
      expect(sentModels.last, equals('openrouter/free'));
      expect(sentModels.length, equals(3));
      expect(body['provider'], equals({'allow_fallbacks': true}));
    });

    test(
        'limita el arreglo models de OpenRouter a <= 3 elementos y reintenta con openrouter/free ante HTTP 400',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR Cache Largo',
        rawApiKey: 'sk-or-test-key-cap3',
        setAsPrimary: true,
      );

      final sentBodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return _jsonResponse({
            'data': [
              {'id': 'vendor/model-a:free'},
              {'id': 'vendor/model-b:free'},
              {'id': 'vendor/model-c:free'},
              {'id': 'vendor/model-d:free'},
              {'id': 'vendor/model-e:free'},
              {'id': 'vendor/model-f:free'},
            ],
          });
        }
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        sentBodies.add(payload);
        if (payload.containsKey('models')) {
          final models = payload['models'] as List;
          expect(models.length, lessThanOrEqualTo(3));
          return _jsonResponse(
            {
              'error': {'message': 'model unavailable'}
            },
            statusCode: 400,
          );
        }
        expect(payload['model'], equals('openrouter/free'));
        return _jsonResponse({
          'model': 'nvidia/nemotron:free',
          'choices': [
            {
              'message': {'content': 'OK via router automático'}
            }
          ],
        });
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );
      router.bindConfigStoreHooks();

      final probe = await configStore.testConnection(AiProviderId.openRouter);
      expect(probe.ok, isTrue);
      expect(probe.activeModel, equals('nvidia/nemotron:free'));
      expect(sentBodies.length, equals(2));
      expect((sentBodies.first['models'] as List).length, equals(3));
      expect(sentBodies.last.containsKey('models'), isFalse);
    });

    test(
        'cuando autoRotateFreeModels está desactivado y hay modelo específico, envía solo ese model sin models/allow_fallbacks',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR Fijo',
        rawApiKey: 'sk-or-fixed-9999',
        preferredModel: 'anthropic/claude-3.5-sonnet',
        setAsPrimary: true,
      );
      final cfg = await configStore.loadConfig();
      await configStore.saveConfig(cfg.copyWith(autoRotateFreeModels: false));

      late Map<String, dynamic> sentBody;
      final client = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({
          'model': 'anthropic/claude-3.5-sonnet',
          'choices': [
            {
              'message': {'content': 'Respuesta modelo fijo'}
            }
          ],
        });
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
      );
      final res = await router.completeChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Test')],
      );

      expect(res.model, equals('anthropic/claude-3.5-sonnet'));
      expect(sentBody['model'], equals('anthropic/claude-3.5-sonnet'));
      expect(sentBody.containsKey('models'), isFalse);
      expect(sentBody.containsKey('provider'), isFalse);
    });
  });

  group('AiProviderRouter - NVIDIA NIM & OpenCode Zen (Cooldown & Rotación)',
      () {
    test(
        'NVIDIA NIM: HTTP 429 con Retry-After marca cooldown y salta al siguiente modelo en la misma llamada y en llamadas subsecuentes',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.nvidiaNim,
        label: 'NIM 1',
        rawApiKey: 'nvapi-key-1111',
        setAsPrimary: true,
      );

      bool failFirstModel = true;
      final requestedModels = <String>[];
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          equals('https://integrate.api.nvidia.com/v1/chat/completions'),
        );
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final model = payload['model'] as String;
        requestedModels.add(model);

        if (failFirstModel && model == 'google/gemma-4-31b-it') {
          return _jsonResponse(
            {
              'error': {'message': 'Rate limit exceeded'}
            },
            statusCode: 429,
            headers: {'Retry-After': '45'},
          );
        }

        return _jsonResponse({
          'model': model,
          'choices': [
            {
              'message': {'content': 'OK desde $model'}
            }
          ],
        });
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );

      // Primera llamada: intenta modelo 1 -> 429 (Retry-After: 45s) -> salta a modelo 2 en la MISMA llamada
      final res1 = await router.completeChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Hola NIM')],
      );
      expect(res1.model, equals('nvidia/nemotron-3.5-lightning-30b-a3b'));
      expect(res1.attempts, equals(2));
      expect(
        requestedModels,
        equals([
          'google/gemma-4-31b-it',
          'nvidia/nemotron-3.5-lightning-30b-a3b',
        ]),
      );
      expect(router.cooldownUntil, isNotEmpty);

      // Segunda llamada a los 20s: debe omitir modelo 1 sin hacer petición HTTP a él
      fakeNow = fakeNow.add(const Duration(seconds: 20));
      requestedModels.clear();
      final res2 = await router.completeChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Segunda')],
      );
      expect(res2.model, equals('nvidia/nemotron-3.5-lightning-30b-a3b'));
      expect(
        requestedModels,
        equals(['nvidia/nemotron-3.5-lightning-30b-a3b']),
      );

      // A los +30s (50s > 45s): el cooldown expiró y modelo 1 vuelve a ser elegible
      failFirstModel = false;
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      requestedModels.clear();
      final res3 = await router.completeChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Tercera')],
      );
      expect(res3.model, equals('google/gemma-4-31b-it'));
      expect(requestedModels, equals(['google/gemma-4-31b-it']));
    });

    test(
        'OpenCode Zen: rota ante 429 (default 60s), 402, 503 y 404 usando catálogo /models cacheado 24h',
        () async {
      final entry = await configStore.addApiKey(
        provider: AiProviderId.openCodeZen,
        label: 'Zen Key',
        rawApiKey: 'zen-key-2222',
        setAsPrimary: true,
      );

      int modelsGetCalls = 0;
      final triedChatModels = <String>[];

      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.toString() == 'https://opencode.ai/zen/v1/models') {
          modelsGetCalls++;
          return _jsonResponse({
            'data': [
              {'id': 'zen-fast-free'},
              {'id': 'zen-backup-free'},
              {'id': 'zen-pro-paid'},
              {'id': 'zen-steady-free'},
              {'id': 'zen-winner-free'},
            ],
          });
        }

        expect(
          request.url.toString(),
          equals('https://opencode.ai/zen/v1/chat/completions'),
        );
        final model = (jsonDecode(request.body)
            as Map<String, dynamic>)['model'] as String;
        triedChatModels.add(model);

        if (model == 'zen-fast-free') {
          return _jsonResponse({'error': 'quota'}, statusCode: 429);
        }
        if (model == 'zen-backup-free') {
          return _jsonResponse({'error': 'payment'}, statusCode: 402);
        }
        if (model == 'zen-steady-free') {
          return _jsonResponse({'error': 'unavailable'}, statusCode: 503);
        }
        if (model == 'zen-winner-free') {
          return _jsonResponse({
            'model': 'zen-winner-free',
            'choices': [
              {
                'message': {'content': 'Éxito en OpenCode Zen'}
              }
            ],
          });
        }
        return _jsonResponse({'error': 'not found'}, statusCode: 404);
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );
      router.bindConfigStoreHooks();

      // Descubrir catálogo (filtra solo los -free) y verificar caché 24h
      final models = await configStore.fetchAvailableModels(
        AiProviderId.openCodeZen,
        keyId: entry.id,
      );
      expect(
        models,
        equals([
          'zen-fast-free',
          'zen-backup-free',
          'zen-steady-free',
          'zen-winner-free',
        ]),
      );
      expect(modelsGetCalls, equals(1));

      // Segunda consulta dentro de 24h no pega a red
      fakeNow = fakeNow.add(const Duration(hours: 12));
      final cachedModels = await configStore.fetchAvailableModels(
        AiProviderId.openCodeZen,
      );
      expect(cachedModels, equals(models));
      expect(modelsGetCalls, equals(1));

      // Ahora completeChat usa el catálogo cacheado y salta 429 -> 402 -> 503 -> 200
      final res = await router.completeChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Hola Zen')],
      );
      expect(res.provider, equals(AiProviderId.openCodeZen));
      expect(res.model, equals('zen-winner-free'));
      expect(res.text, equals('Éxito en OpenCode Zen'));
      expect(
        triedChatModels,
        equals([
          'zen-fast-free',
          'zen-backup-free',
          'zen-steady-free',
          'zen-winner-free',
        ]),
      );
      // Cooldown default de 60s aplicado al 429 sin Retry-After
      expect(
        router.isModelInCooldown(
          AiProviderId.openCodeZen,
          'zen-fast-free',
          keyId: entry.id,
        ),
        isTrue,
      );
      fakeNow = fakeNow.add(const Duration(seconds: 61));
      expect(
        router.isModelInCooldown(
          AiProviderId.openCodeZen,
          'zen-fast-free',
          keyId: entry.id,
        ),
        isFalse,
      );

      // Tras >24h desde fetch, el caché expira y vuelve a consultar /models
      fakeNow = fakeNow.add(const Duration(hours: 13));
      await configStore.fetchAvailableModels(AiProviderId.openCodeZen);
      expect(modelsGetCalls, equals(2));
    });
  });

  group('AiProviderRouter - Multi-API Key y Cross-Provider Fallback', () {
    test(
        'rota a la siguiente API Key habilitada del mismo proveedor (saltando deshabilitadas)',
        () async {
      final key1 = await configStore.addApiKey(
        provider: AiProviderId.nvidiaNim,
        label: 'Key 1 Agotada',
        rawApiKey: 'nvapi-first-1111',
        setAsPrimary: true,
      );
      final key2Disabled = await configStore.addApiKey(
        provider: AiProviderId.nvidiaNim,
        label: 'Key 2 Deshabilitada',
        rawApiKey: 'nvapi-second-2222',
      );
      await configStore.updateApiKey(key2Disabled.copyWith(isEnabled: false));
      final key3 = await configStore.addApiKey(
        provider: AiProviderId.nvidiaNim,
        label: 'Key 3 Buena',
        rawApiKey: 'nvapi-third-3333',
      );

      final authHeadersSeen = <String>[];
      final client = MockClient((request) async {
        final auth = request.headers['Authorization'] ?? '';
        authHeadersSeen.add(auth);
        if (auth == 'Bearer nvapi-first-1111') {
          return _jsonResponse({'error': 'rate limit'}, statusCode: 429);
        }
        if (auth == 'Bearer nvapi-third-3333') {
          return _jsonResponse({
            'model': 'meta/llama-3.3-70b-instruct',
            'choices': [
              {
                'message': {'content': 'Respondido con Key 3'}
              }
            ],
          });
        }
        return _jsonResponse({'error': 'unexpected key'}, statusCode: 500);
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );

      final res = await router.completeChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Balance')],
      );

      expect(res.keyId, equals(key3.id));
      expect(res.text, equals('Respondido con Key 3'));
      expect(res.usedFallbackProvider, isFalse);
      expect(authHeadersSeen, isNot(contains('Bearer nvapi-second-2222')));
      expect(authHeadersSeen.first, equals('Bearer nvapi-first-1111'));
      expect(authHeadersSeen.last, equals('Bearer nvapi-third-3333'));
      expect(key1.id != key3.id, isTrue);
    });

    test(
        'crossProviderFallback == true salta al siguiente proveedor Cloud habilitado; si es false falla sin saltar',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.nvidiaNim,
        label: 'NIM Primary',
        rawApiKey: 'nvapi-exhausted-0001',
        setAsPrimary: true,
      );
      await configStore.addApiKey(
        provider: AiProviderId.gemini,
        label: 'Gemini Backup',
        rawApiKey: 'AIza-backup-key-9999',
      );

      final visitedUrls = <String>[];
      final client = MockClient((request) async {
        visitedUrls.add(request.url.toString());
        if (request.url.host == 'integrate.api.nvidia.com') {
          return _jsonResponse({'error': 'exhausted'}, statusCode: 429);
        }
        if (request.url.host == 'generativelanguage.googleapis.com') {
          return _jsonResponse({
            'model': 'gemini-2.5-flash',
            'choices': [
              {
                'message': {'content': 'Respaldo exitoso desde Gemini'}
              }
            ],
          });
        }
        return _jsonResponse({}, statusCode: 404);
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );

      // Con crossProviderFallback == false (default): NO debe invocar Gemini
      await expectLater(
        () => router.completeChat(
          messages: const [AiRouterMessage(role: 'user', content: 'Test')],
        ),
        throwsA(isA<AiRouterException>()),
      );
      expect(
        visitedUrls.any((u) => u.contains('generativelanguage.googleapis.com')),
        isFalse,
      );

      // Activar crossProviderFallback == true y limpiar cooldowns
      router.clearCooldowns();
      visitedUrls.clear();
      final cfg = await configStore.loadConfig();
      await configStore.saveConfig(cfg.copyWith(crossProviderFallback: true));

      final res = await router.completeChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Test')],
      );
      expect(res.provider, equals(AiProviderId.gemini));
      expect(res.model, equals('gemini-2.5-flash'));
      expect(res.usedFallbackProvider, isTrue);
      expect(res.text, equals('Respaldo exitoso desde Gemini'));
      expect(
        visitedUrls.any((u) => u.contains('generativelanguage.googleapis.com')),
        isTrue,
      );
    });
  });

  group('AiProviderRouter - Hooks testConnection / fetchAvailableModels & SSE',
      () {
    test('testConnection valida /models + /chat/completions y maneja 401',
        () async {
      final goodKey = await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR Good',
        rawApiKey: 'sk-or-good-1234',
        setAsPrimary: true,
      );
      final badKey = await configStore.addApiKey(
        provider: AiProviderId.openAi,
        label: 'OpenAI Bad',
        rawApiKey: 'sk-openai-bad-0000',
      );

      final client = MockClient((request) async {
        if (request.url.host == 'openrouter.ai' && request.method == 'GET') {
          return _jsonResponse({
            'data': [
              {'id': 'google/gemma-3-27b-it:free'},
              {'id': 'openai/gpt-4o'},
              {'id': 'qwen/qwen-2.5-72b-instruct:free'},
            ],
          });
        }
        if (request.url.host == 'openrouter.ai' && request.method == 'POST') {
          return _jsonResponse({
            'model': 'google/gemma-3-27b-it:free',
            'choices': [
              {
                'message': {'content': 'OK'}
              }
            ],
          });
        }
        if (request.url.host == 'api.openai.com') {
          return _jsonResponse({'error': 'invalid key'}, statusCode: 401);
        }
        return _jsonResponse({}, statusCode: 404);
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );
      router.bindConfigStoreHooks();

      final okProbe = await configStore.testConnection(
        AiProviderId.openRouter,
        keyId: goodKey.id,
      );
      expect(okProbe.ok, isTrue);
      expect(okProbe.activeModel, equals('google/gemma-3-27b-it:free'));
      expect(
        okProbe.discoveredModels,
        equals([
          'google/gemma-3-27b-it:free',
          'qwen/qwen-2.5-72b-instruct:free',
          'openrouter/free',
        ]),
      );

      final badProbe = await configStore.testConnection(
        AiProviderId.openAi,
        keyId: badKey.id,
      );
      expect(badProbe.ok, isFalse);
      expect(badProbe.message, contains('401'));
    });

    test(
        'OpenAI filtra modelos no-chat, prioriza gpt-4o-mini/4.1-mini, usa max_completion_tokens en o3 y preserva detalle 429',
        () async {
      final openaiKey = await configStore.addApiKey(
        provider: AiProviderId.openAi,
        label: 'OpenAI Quota',
        rawApiKey: 'sk-proj-test-quota',
        setAsPrimary: true,
      );

      final sentPayloads = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return _jsonResponse({
            'data': [
              {'id': 'o3-2025-04-16'},
              {'id': 'gpt-image-2.5-sunburst'},
              {'id': 'gpt-4o-realtime-preview'},
              {'id': 'gpt-5.2-2025-12-11'},
              {'id': 'gpt-4.1-mini'},
              {'id': 'gpt-4o-mini'},
            ],
          });
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentPayloads.add(body);
        return _jsonResponse(
          {
            'error': {
              'message':
                  'You exceeded your current quota, please check your plan and billing details.'
            }
          },
          statusCode: 429,
        );
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );
      router.bindConfigStoreHooks();

      final probe = await configStore.testConnection(
        AiProviderId.openAi,
        keyId: openaiKey.id,
      );
      expect(probe.ok, isFalse);
      expect(probe.message, contains('You exceeded your current quota'));
      expect(probe.message, contains('billing'));
      expect(
        probe.discoveredModels,
        equals([
          'gpt-4o-mini',
          'gpt-4.1-mini',
          'o3-2025-04-16',
          'gpt-5.2-2025-12-11',
        ]),
      );
      // Confirmar que o3 recibió max_completion_tokens sin temperature
      final o3Payload =
          sentPayloads.firstWhere((p) => p['model'] == 'o3-2025-04-16');
      expect(o3Payload.containsKey('max_completion_tokens'), isTrue);
      expect(o3Payload.containsKey('max_tokens'), isFalse);
      expect(o3Payload.containsKey('temperature'), isFalse);
      final miniPayload =
          sentPayloads.firstWhere((p) => p['model'] == 'gpt-4o-mini');
      expect(miniPayload.containsKey('max_tokens'), isTrue);
      expect(miniPayload.containsKey('temperature'), isTrue);
    });

    test('streamChat decodifica eventos SSE y rota tras HTTP 429', () async {
      await configStore.addApiKey(
        provider: AiProviderId.nvidiaNim,
        label: 'NIM Stream',
        rawApiKey: 'nvapi-stream-1234',
        setAsPrimary: true,
      );

      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['stream'], isTrue);
        if (body['model'] == 'google/gemma-4-31b-it') {
          return _jsonResponse({'error': 'busy'}, statusCode: 429);
        }
        final sse = [
          'data: {"model":"nvidia/nemotron-3.5-lightning-30b-a3b","choices":[{"delta":{"content":"Hola "}}]}',
          '',
          'data: {"model":"nvidia/nemotron-3.5-lightning-30b-a3b","choices":[{"delta":{"content":"Moneo"}}]}',
          '',
          'data: [DONE]',
          '',
        ].join('\n');
        return http.Response.bytes(
          utf8.encode(sse),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );

      final chunks = await router.streamChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Di hola')],
      ).toList();

      expect(chunks.map((c) => c.delta).join(), equals('Hola Moneo'));
      expect(
        chunks.first.model,
        equals('nvidia/nemotron-3.5-lightning-30b-a3b'),
      );
    });

    test(
        'testConnection usa max_tokens >= 256 para modelos reasoning, reintenta openrouter/free ante content vacío y marca 410 Gone en NVIDIA',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR Reasoning Probe',
        rawApiKey: 'sk-or-reasoning-1234',
        setAsPrimary: true,
      );

      final openRouterBodies = <Map<String, dynamic>>[];
      final orClient = MockClient((request) async {
        if (request.method == 'GET') {
          return _jsonResponse({
            'data': [
              {'id': 'inclusionai/ling-3.2-flash:free'},
              {'id': 'baidu/ernie-5.5-flash-preview:free'},
            ],
          });
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        openRouterBodies.add(body);
        if (body.containsKey('models')) {
          return _jsonResponse({
            'model': 'inclusionai/ling-3.2-flash:free',
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': '',
                  'reasoning': 'pensando...',
                }
              }
            ],
          });
        }
        return _jsonResponse({
          'model': 'google/gemma-4-31b-it:free',
          'choices': [
            {
              'message': {'content': 'OK'}
            }
          ],
        });
      });

      final orRouter = AiProviderRouter(
        httpClient: orClient,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );
      final orProbe = await orRouter.testConnection(AiProviderId.openRouter);
      expect(orProbe.ok, isTrue);
      expect(orProbe.activeModel, equals('google/gemma-4-31b-it:free'));
      expect(openRouterBodies.first['max_tokens'], greaterThanOrEqualTo(256));

      await configStore.addApiKey(
        provider: AiProviderId.nvidiaNim,
        label: 'NVIDIA 410',
        rawApiKey: 'nvapi-test-410',
        setAsPrimary: true,
      );
      final nimClient = MockClient((request) async {
        if (request.method == 'GET') {
          return _jsonResponse({}, statusCode: 404);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['model'] == 'google/gemma-4-31b-it') {
          return _jsonResponse(
            {
              'title': 'Gone',
              'status': 410,
              'detail': 'Model reached end of life.',
            },
            statusCode: 410,
          );
        }
        return _jsonResponse({
          'model': body['model'],
          'choices': [
            {
              'message': {'content': 'OK'}
            }
          ],
        });
      });

      final nimRouter = AiProviderRouter(
        httpClient: nimClient,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );
      final nimProbe = await nimRouter.testConnection(AiProviderId.nvidiaNim);
      expect(nimProbe.ok, isTrue);
      expect(nimProbe.activeModel,
          equals('nvidia/nemotron-3.5-lightning-30b-a3b'));
      expect(
        nimRouter.isModelInCooldown(
          AiProviderId.nvidiaNim,
          'google/gemma-4-31b-it',
        ),
        isTrue,
      );
    });
  });

  group('GemmaClassifierAdapter - Integración Multi-IA y strategic_note', () {
    test('buildCompactPrompt incluye strategic_note y respeta sandbox', () {
      final prompt = GemmaClassifierAdapter.buildCompactPrompt(
        rawText: 'Compra \$50.000 en Cafetería Central',
        amount: 50000,
      );
      expect(prompt, contains('strategic_note'));
      expect(prompt, contains('<notificacion_no_confiable>'));
    });

    test(
        'en modo Cloud invoca AiProviderRouter y retorna strategic_note; en simulator retorna null rápido',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR Classifier',
        rawApiKey: 'sk-or-classifier-5678',
        setAsPrimary: true,
      );

      int httpCalls = 0;
      final client = MockClient((request) async {
        httpCalls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final userContent =
            (body['messages'] as List).last['content'] as String;
        expect(userContent, contains('<notificacion_no_confiable>'));
        return _jsonResponse({
          'model': 'google/gemma-3-27b-it:free',
          'choices': [
            {
              'message': {
                'content':
                    '{"classification":"gasto","category":"Alimentación","confidence":0.92,"strategic_note":"Consumo habitual en restaurante"}',
              },
            },
          ],
        });
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
      );
      final adapter = GemmaClassifierAdapter(
        configStore: configStore,
        router: router,
      );

      final cloudResult = await adapter.classify(
        rawText: 'Pago \$32.000 en Bistro 21',
        merchant: 'Bistro 21',
        amount: 32000,
      );
      expect(httpCalls, equals(1));
      expect(cloudResult, isNotNull);
      expect(cloudResult!.classification, equals('gasto'));
      expect(cloudResult.category, equals('Alimentación'));
      expect(
        cloudResult.strategicNote,
        equals('Consumo habitual en restaurante'),
      );

      // En modo simulator debe devolver null sin tocar red ni disparar fallos
      await configStore.setPrimaryProvider(AiProviderId.simulator);
      final simResult = await adapter.classify(
        rawText: 'Pago \$10.000 en Comercio',
      );
      expect(simResult, isNull);
      expect(httpCalls, equals(1));
      expect(adapter.consecutiveFailures, equals(0));
    });

    test('cuando se inyecta GemmaInferenceClient en constructor no toca red',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR Ignored',
        rawApiKey: 'sk-or-ignored-0000',
        setAsPrimary: true,
      );

      int httpCalls = 0;
      final router = AiProviderRouter(
        httpClient: MockClient((_) async {
          httpCalls++;
          return _jsonResponse({}, statusCode: 500);
        }),
        configStore: configStore,
      );
      final injected = _NoNetworkGemmaClient();
      final adapter = GemmaClassifierAdapter(
        client: injected,
        configStore: configStore,
        router: router,
      );

      final res = await adapter.classify(rawText: 'Compra local');
      expect(injected.calls, equals(1));
      expect(httpCalls, equals(0));
      expect(res?.strategicNote, equals('Cliente inyectado'));
    });
  });

  group('AiChatService - Enrutamiento Cloud e Inactividad Gemma', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('moneo_router_chat_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AdddataAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ResponsibilityAdapter());
      }
    });

    setUp(() async {
      final box = Hive.isBoxOpen('data')
          ? Hive.box<Add_data>('data')
          : await Hive.openBox<Add_data>('data');
      await box.clear();
      await ResponsibilityService.init();
      final chat = AiChatService();
      await chat.resetGemmaSessionForTests();
      chat.testSessionCreator = null;
      chat.testConfigStore = null;
      chat.testRouter = null;
      chat.gemmaIdleTimeout = const Duration(minutes: 2);
    });

    tearDown(() async {
      final chat = AiChatService();
      await chat.resetGemmaSessionForTests();
      chat.testSessionCreator = null;
      chat.testConfigStore = null;
      chat.testRouter = null;
      chat.gemmaIdleTimeout = const Duration(minutes: 2);
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        'enruta sendMessage a AiProviderRouter cuando IA Principal es Cloud y actualiza etiqueta de modelo',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR Chat',
        rawApiKey: 'sk-or-chat-4321',
        setAsPrimary: true,
      );

      final client = MockClient((request) async {
        return _jsonResponse({
          'model': 'google/gemma-3-27b-it:free',
          'choices': [
            {
              'message': {
                'content': 'Tu balance actual te permite ahorrar con calma.',
              },
            },
          ],
        });
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
      );

      final chat = AiChatService();
      chat.testConfigStore = configStore;
      chat.testRouter = router;
      await chat.initialize();

      expect(chat.activeProvider, equals(AiProviderId.openRouter));
      expect(chat.useLocalSimulator, isFalse);

      await chat.sendMessage('¿Cómo puedo mejorar mi ahorro?');

      expect(
        chat.messages.last.content,
        equals('Tu balance actual te permite ahorrar con calma.'),
      );
      expect(chat.lastUsedProvider, equals(AiProviderId.openRouter));
      expect(chat.lastUsedModel, equals('google/gemma-3-27b-it:free'));
      expect(
        chat.lastUsedModelLabel,
        equals('OpenRouter · google/gemma-3-27b-it:free'),
      );
    });

    test(
        'modo Local Gemma cierra sesión automáticamente tras inactividad y recarga bajo demanda',
        () async {
      int sessionCreations = 0;
      late _FakeLocalChatSession activeFakeSession;

      final chat = AiChatService();
      chat.testConfigStore = configStore;
      chat.gemmaIdleTimeout = const Duration(milliseconds: 50);
      chat.testSessionCreator = (_) async {
        sessionCreations++;
        activeFakeSession = _FakeLocalChatSession();
        return activeFakeSession;
      };

      await chat.initialize();
      await chat.setSimulatorMode(false);

      await chat.sendMessage('Primer mensaje local');
      expect(sessionCreations, equals(1));
      expect(chat.isGemmaSessionActive, isTrue);
      expect(activeFakeSession.closed, isFalse);

      // Esperar descarga automática por inactividad
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(activeFakeSession.closed, isTrue);
      expect(chat.isGemmaSessionActive, isFalse);
      expect(chat.idleUnloadCount, greaterThanOrEqualTo(1));

      // Nuevo mensaje recarga sesión bajo demanda
      await chat.sendMessage('Segundo mensaje local');
      expect(sessionCreations, equals(2));
      expect(chat.isGemmaSessionActive, isTrue);
    });

    test(
        'en modo Cloud ante fallo de red repliega al simulador offline sin perder el turno',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.openAi,
        label: 'OpenAI Offline',
        rawApiKey: 'sk-openai-offline-1234',
        setAsPrimary: true,
      );

      final router = AiProviderRouter(
        httpClient: MockClient((_) async => _jsonResponse({}, statusCode: 503)),
        configStore: configStore,
      );

      final chat = AiChatService();
      chat.testConfigStore = configStore;
      chat.testRouter = router;
      await chat.initialize();

      await chat.sendMessage('hola');
      expect(
        chat.messages.last.content,
        contains('simulador financiero respondió offline'),
      );
      expect(chat.isGenerating, isFalse);
    });
  });

  group(
      'AiProviderRouter - Google Gemini & GemmaClassifierAdapter Circuit-Breaker Cloud',
      () {
    test('Google Gemini normaliza prefijo models/ en /models y completa chat',
        () async {
      final entry = await configStore.addApiKey(
        provider: AiProviderId.gemini,
        label: 'Gemini Key',
        rawApiKey: 'AIza-test-gemini-key',
        setAsPrimary: true,
      );

      final client = MockClient((request) async {
        expect(request.url.host, equals('generativelanguage.googleapis.com'));
        if (request.method == 'GET') {
          return _jsonResponse({
            'data': [
              {'id': 'models/gemini-2.5-flash'},
              {'id': 'models/gemini-2.5-flash-lite'},
              {'id': 'models/text-embedding-004'},
            ],
          });
        }
        return _jsonResponse({
          'model': 'gemini-2.5-flash',
          'choices': [
            {
              'message': {'content': 'Respuesta Gemini OK'}
            }
          ],
        });
      });

      final router = AiProviderRouter(
        httpClient: client,
        configStore: configStore,
        nowProvider: () => fakeNow,
      );
      router.bindConfigStoreHooks();

      final models = await configStore.fetchAvailableModels(
        AiProviderId.gemini,
        keyId: entry.id,
      );
      expect(
        models,
        equals(['gemini-2.5-flash', 'gemini-2.5-flash-lite']),
      );

      final res = await router.completeChat(
        messages: const [AiRouterMessage(role: 'user', content: 'Hola')],
      );
      expect(res.provider, equals(AiProviderId.gemini));
      expect(res.model, equals('gemini-2.5-flash'));
      expect(res.text, equals('Respuesta Gemini OK'));
    });

    test(
        'GemmaClassifierAdapter en modo Cloud abre circuit-breaker tras 2 fallos/timeouts',
        () async {
      await configStore.addApiKey(
        provider: AiProviderId.openRouter,
        label: 'OR CB',
        rawApiKey: 'sk-or-cb-1234',
        setAsPrimary: true,
      );

      int httpCalls = 0;
      final router = AiProviderRouter(
        httpClient: MockClient((_) async {
          httpCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return _jsonResponse({}, statusCode: 503);
        }),
        configStore: configStore,
      );

      final adapter = GemmaClassifierAdapter(
        configStore: configStore,
        router: router,
        cloudTimeout: const Duration(milliseconds: 30),
        failureThreshold: 2,
        cooldownDuration: const Duration(minutes: 5),
        nowProvider: () => fakeNow,
      );

      expect(await adapter.classify(rawText: 'Compra 1'), isNull);
      expect(adapter.consecutiveFailures, equals(1));
      expect(await adapter.classify(rawText: 'Compra 2'), isNull);
      expect(adapter.consecutiveFailures, equals(2));
      expect(adapter.isCircuitOpen, isTrue);

      final callsAtOpen = httpCalls;
      expect(await adapter.classify(rawText: 'Compra 3'), isNull);
      expect(httpCalls, equals(callsAtOpen));
    });
  });
}
