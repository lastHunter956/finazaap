# Tareas — `notificaciones-rag-y-multi-ia`

## Fase 0: Fundación y Contratos
- [x] Crear rama `integration/notificaciones-rag-y-multi-ia` desde `main`.
- [x] Declarar `http: ^1.3.0` en `pubspec.yaml` y verificar `flutter pub get --offline` en Docker.
- [ ] Crear `spec.md`, `plan.md`, `tasks.md` y contrato compartido `lib/services/ai_provider_config.dart`.

## Fase 1: Implementación en Paralelo (4 Agentes)
- [ ] **Agente 1 (Mini-RAG y Clasificador):** Índice compacto en RAM, ecuación híbrida `< 1 ms`, aliases/paquetes en `LearnedPattern`, resolución en Etapa 1 (`Score >= 0.88`), `strategicNote` + tests unitarios.
- [ ] **Agente 2 (Correlación Multi-App y Feedback Loop):** Anillo de movimientos recientes (48 h), aprendizaje automático de `DedupRule` al editar 1 y descartar duplicados, agrupación de 4 apps en 1 tarjeta + tests unitarios.
- [ ] **Agente 3 (Router Multi-IA y Carga Lazy):** `AiProviderRouter` con OpenRouter/NVIDIA/OpenCode/Gemini/OpenAI + rotación ante `429` + multi-API key + `FlutterGemma` lazy/unload en `main.dart`/`AiChatService` + `GemmaClassifierAdapter` unificado + tests con mock HTTP.
- [ ] **Agente 4 (UI Bandeja y Ajustes Multi-IA):** `strategicNote` + Agrupar/Separar en `PendingTransactionsScreen`/`PendingTransactionCard`, gestor multi-API y selector de **IA Principal** en `SettingsScreen` y `AiChatScreen` + widget tests.

## Fase 2: Integración y Checkpoint Final
- [ ] Integrar las 4 ramas en `integration/notificaciones-rag-y-multi-ia`.
- [ ] Ejecutar `docker-compose exec -T flutter-env dart analyze` (`No issues found!`).
- [ ] Ejecutar `docker-compose exec -T flutter-env flutter test --no-pub -j 1` (100% en verde).
- [ ] Limpiar los 4 worktrees temporales y dejar lista `integration/notificaciones-rag-y-multi-ia` para validación humana.
