# Especificación — Notificaciones con Mini-RAG, Aprendizaje Multi-App y Motor Multi-IA (`notificaciones-rag-y-multi-ia`)

> **Módulo:** `notificaciones-rag-y-multi-ia`
> **Base:** `0b8cd3a` (`main`)
> **Rama de integración:** `integration/notificaciones-rag-y-multi-ia`

---

## 1. Objetivo y Alcance

Evolucionar el pipeline de notificaciones bancarias y el motor de IA de Moneo (`finazaap`) manteniendo compatibilidad con las cajas Hive cifradas existentes (`learned_patterns`, `pending_notifications`, `notification_dedup_history`, `notification_executed_ids`, `notification_dedup_rules`) y los invariantes de seguridad/aislamiento contable:

1. **Aprendizaje Real y Correlación Multi-App (`4 avisos → 1 tarjeta`):**
   - Detectar y agrupar notificaciones duplicadas o complementarias provenientes de distintas apps/canales (banco, billetera, correo, SMS) tanto contra la bandeja pendiente como contra un anillo de movimientos recientes confirmados (`48 h`, máx. `100` entradas).
   - Aprender automáticamente una `DedupRule` multi-app cuando el usuario confirma/corrige 1 notificación y descarta las demás del mismo monto (`roundedAmount`) dentro de una ventana `< 30 min`.
   - Exponer en la UI de `PendingTransactionsScreen` / `PendingTransactionCard` el estado agrupado (`Agrupada (N avisos)`), botón **Separar** (`splitMergedItem`) y selección múltiple para **Agrupar en 1** (`mergePendingItems`), además del bloque de comentario inteligente (`strategicNote`).

2. **Mini-RAG Semántico en Disco (`< 1 ms` y bajo uso de caché RAM):**
   - Mantener los patrones completos persistidos en disco en la caja cifrada `learned_patterns`, conservando en RAM únicamente cabeceras compactas e índice invertido (`< 40 KB` para 500 patrones) y cargando el registro completo solo para los top-K candidatos.
   - Soportar `aliases` (variantes textuales del comercio) y `knownPackages` en `LearnedPattern` (retrocompatible con entradas JSON previas).
   - Evaluar similitud híbrida en `< 1 ms`:
     $$\text{Score}(q, p) = 0.40 \cdot \text{BM25} + 0.35 \cdot \text{Jaccard}_{3\text{-gram}} + 0.15 \cdot \text{PkgMatch} + 0.10 \cdot \text{ConfBoost}$$
   - Resolver directamente en **Etapa 1** (`learned_patterns`) cuando `Score >= 0.88` (si el patrón no está `en_revision`), sin despertar al LLM.
   - Generar `strategicNote` explicativo usando `MonthlySummaryCache` en $O(1)$ para Etapa 1/2 y mediante el JSON del LLM en Etapa 3.

3. **Motor IA Exclusivo (Local o Multi-API Cloud) con Auto-Rotación Gratuita:**
   - El usuario puede registrar **múltiples API Keys de varios distribuidores** (`OpenRouter`, `NVIDIA NIM / build.nvidia.com`, `OpenCode Zen`, `Google Gemini`, `OpenAI GPT`), además de configurar **Local Gemma 4 E2B (default)**, **Local HuggingFace (`.litertlm`)** o **Simulador Local**.
   - El usuario elige **1 IA Principal activa** que reemplaza el motor de **Notificaciones (Etapa 3), Reportes y Chat de IA**.
   - **Carga óptima:** Si la IA Principal es Cloud o Simulador, `FlutterGemma` **no** se inicializa ni carga en RAM al arrancar la app (`main.dart`). Si es Local, carga bajo demanda (*lazy*) y libera sesión tras 2 minutos de inactividad.
   - **Failover automático ante agotamiento (`HTTP 429` / `402` / `503`):**
     - **OpenRouter:** envía lista `models` de opciones `:free` + `"openrouter/free"` (`allow_fallbacks: true`).
     - **NVIDIA NIM & OpenCode Zen:** descubre catálogo (`GET /v1/models` cacheado 24 h) y rota en cliente con mapa de *cooldown* por modelo y por API Key adicional del mismo proveedor.
     - **Respaldo cruzado opcional:** si se activa `crossProviderFallback`, rota a otro proveedor Cloud configurado cuando se agote el principal, y finalmente degrada de forma segura a reglas locales sin bloquear la app.
   - **Seguridad de API Keys:** las claves crudas viven exclusivamente en `FlutterSecureStorage` (`ai_provider_secret_<id>`); en `SharedPreferences` solo se guardan metadatos y máscara (`sk-...1234`).

---

## 2. Restricciones Inviolables

- **NO modificar Archivos Protegidos:** `lib/data/transaction_service.dart`, `lib/data/credit_card_calculator.dart`, `lib/data/model/*.g.dart`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, `lib/core/security/*`.
- **NO hacer commits directos en `main`.**
- **Privacidad de notificaciones:** nunca enviar texto completo de notificaciones si el usuario eligió modo Local/Simulador; en modo Cloud (solo cuando el usuario lo selecciona explícitamente como IA Principal), usar el prompt sanitizado compacto (`<notificacion_no_confiable>`, sin saldos ni historial de la caja `'data'`).
- **Aislamiento contable:** mientras un ítem está en `pending_notifications`, nunca modifica saldos ni la caja `'data'`.
- **Validación:** `dart analyze` (`0` issues) + `flutter test --no-pub -j 1` en Docker (`finazaap-flutter`).
