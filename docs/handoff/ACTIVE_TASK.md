# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `integration/notificaciones-rag-y-multi-ia` (integrada desde los 4 agentes paralelos y validada en Docker; **permanece hasta validación humana del usuario**, sin merge a `main` ni `git push`)
> **Worktrees activos paralelos no relacionados:** `wt-f2-archive` (`agent/perf/archive-service-y-backup-v2`) y `wt-maestro-agentic` (`agent/maestro/configuracion-agentica`).

## Pendientes reales
1. [ ] **Validación humana en la aplicación (`integration/notificaciones-rag-y-multi-ia`):** Probar Mini-RAG de notificaciones, agrupación multi-app, `strategicNote`, botones Agrupar/Separar, registro de múltiples API Keys (OpenRouter / NVIDIA NIM / OpenCode Zen / Gemini / OpenAI), selección de IA Principal y modos locales Gemma 4 / HuggingFace antes de fusionar a `main`.
2. [ ] **Validación física en Android (cuando el usuario apruebe `adb install`):** Instalar APK compilado y completar la matriz de validación de notificaciones reales en `R5CY21GE9YY`.
3. [ ] **Fase 2 (`wt-f2-archive`):** Implementar/finalizar `ArchiveService` + `DataManagementService` v2 + suite de pruebas en Docker.
4. [ ] **Fase 3 (requiere aprobación explícita):** Hooks mínimos en `credit_card_calculator.dart` y `transaction_service.dart` + selector de años archivados en `Statistics`.
5. [ ] `git push` a `origin/main` (solo con autorización explícita del usuario).
