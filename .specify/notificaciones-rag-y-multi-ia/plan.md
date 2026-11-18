# Plan Técnico — Notificaciones con Mini-RAG, Aprendizaje Multi-App y Motor Multi-IA

> **Rama de integración:** `integration/notificaciones-rag-y-multi-ia`
> **Base:** `0b8cd3a` (`main`)

---

## 1. Contratos Base (Fase 0)

- `pubspec.yaml`: promover `http: ^1.3.0` (ya presente en `pubspec.lock`) a dependencia directa multiplataforma (Android/iOS/Web/VM).
- `lib/services/ai_provider_config.dart`: define `AiProviderId`, `AiApiKeyEntry`, `AiEngineConfig` y `AiProviderConfigStore` (`ChangeNotifier` con almacenamiento seguro vía `SecureKeyStore` y hooks `connectionTester` / `modelsRefresher`) para desacoplar completamente al Agente 3 (Router/IA) del Agente 4 (UI Ajustes/Chat).

---

## 2. Partición en 4 Worktrees Paralelos (Cero Solapamiento de Archivos)

### Agente 1 — Mini-RAG en Disco y Clasificador (`agent/rag/indice-semantico-y-patrones`)
- **Modelo:** `gemini-4-hydrogen-high`
- **Archivos propios:**
  - `lib/features/notifications/services/text_similarity_index.dart`
  - `lib/features/notifications/domain/models/learned_pattern.dart`
  - `lib/features/notifications/services/learned_patterns_service.dart`
  - `lib/features/notifications/services/transaction_classifier.dart`
  - `test/features/notifications/services/learned_patterns_rag_test.dart`
- **Responsabilidad:** índice compacto en memoria + *posting list*, lectura perezosa de Hive, ecuación híbrida `< 1 ms`, resolución semántica en Etapa 1 (`Score >= 0.88`), soporte de `aliases`/`knownPackages`, y generación de `strategicNote` en Etapa 1/2/3.

### Agente 2 — Correlación Multi-App y Feedback Loop (`agent/dedup/correlacion-multi-app`)
- **Modelo:** `gemini-4-hydrogen-high`
- **Archivos propios:**
  - `lib/features/notifications/domain/models/dedup_models.dart`
  - `lib/features/notifications/services/transaction_dedup_correlator.dart`
  - `lib/features/notifications/services/notification_pipeline_service.dart`
  - `lib/features/notifications/presentation/notifiers/pending_transactions_notifier.dart`
  - `test/features/notifications/services/multi_app_dedup_learning_test.dart`
- **Responsabilidad:** anillo de movimientos confirmados (`48 h` / máx. `100`), aprendizaje automático de `DedupRule` multi-app cuando se confirma/corrige 1 y se descartan otras del mismo monto en `< 30 min`, fusión automática de 4 apps en 1 tarjeta con `strategicNote` de fuentes agrupadas.

### Agente 3 — Router Multi-Proveedor, Multi-API Key y Carga Lazy (`agent/ai/router-multi-proveedor`)
- **Modelo:** `gemini-4-hydrogen-xhigh`
- **Archivos propios:**
  - `lib/services/ai_provider_router.dart`
  - `lib/features/notifications/services/gemma_classifier_adapter.dart`
  - `lib/services/ai_chat_service.dart`
  - `lib/main.dart`
  - `test/services/ai_provider_router_test.dart`
- **Responsabilidad:** cliente HTTP unificado para OpenRouter (cola `models` + `openrouter/free`), NVIDIA NIM, OpenCode Zen, Gemini y OpenAI; manejo de `HTTP 429/402/503` con mapa de *cooldown* y rotación por modelo/key/proveedor; descubrimiento de modelos `/v1/models` cacheado 24 h; conexión como **IA Principal** en `GemmaClassifierAdapter` y `AiChatService`; inicialización *lazy* y descarga por inactividad de `FlutterGemma` en `main.dart` y `AiChatService`.

### Agente 4 — UI Bandeja Agrupada y Panel Multi-IA en Ajustes (`agent/ui/bandeja-y-ajustes-ia`)
- **Modelo:** `gemini-4-hydrogen-medium`
- **Archivos propios:**
  - `lib/features/notifications/presentation/widgets/pending_transaction_card.dart`
  - `lib/features/notifications/presentation/screens/pending_transactions_screen.dart`
  - `lib/Screens/settings_screen.dart`
  - `lib/Screens/ai_chat_screen.dart`
  - `test/features/notifications/presentation/pending_grouped_card_test.dart`
  - `test/widgets/ai_provider_settings_test.dart`
- **Responsabilidad:** mostrar `strategicNote`, badge `"Agrupada (N avisos)"`, botón **Separar** (`splitMergedItem`) y modo selección para **Agrupar en 1** (`mergePendingItems`); construir el panel de configuración Multi-IA en `SettingsScreen` y acceso desde `AiChatScreen` (agregar/eliminar varias API keys por proveedor, elegir **IA Principal**, switch de respaldo cruzado, probar conexión / listar modelos gratuitos, URL HuggingFace / Gemma 4 default) respetando `AppTheme`, WCAG AA y targets `>= 48dp`.

---

## 3. Integración y Verificación Final
1. Fusionar las 4 ramas de agentes en `integration/notificaciones-rag-y-multi-ia`.
2. Ejecutar en Docker (`finazaap-flutter`): `dart analyze` y `flutter test --no-pub -j 1`.
3. Verificar compilación Web (`flutter build web --no-pub --no-tree-shake-icons`) si aplica.
4. Limpiar worktrees/ramas temporales de los 4 agentes y **conservar `integration/notificaciones-rag-y-multi-ia`** para validación humana del usuario.
