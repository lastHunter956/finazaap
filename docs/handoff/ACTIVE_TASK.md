# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `integration/notificaciones-rag-y-multi-ia` @ `2e540b8` (consolidada desde `agent/claude/notificaciones-ia-y-spam`, validada en Docker `170/170`, APK `prod` release compilado y listo para firma local + validación humana en Android antes de fusionar a `main`)
> **Worktrees activos paralelos no relacionados:** `wt-f2-archive` (`agent/perf/archive-service-y-backup-v2`) y `wt-maestro-agentic` (`agent/maestro/configuracion-agentica`).

## Pendientes reales
1. [x] **Consolidar `agent/claude/notificaciones-ia-y-spam` → `integration/notificaciones-rag-y-multi-ia`** (`2e540b8`, *fast-forward*) y recompilar APK `prod` release (`bd76ab0137b80be71d9aa855971aa4bd306416a60ce4eacb523d2ebe465ffb4d`, `libapp.so`: `91c8445459758e505257217993d5a1122d8a859114fb00a013e6d21af7c73dbe`).
2. [ ] **Validación humana en Android (`integration/notificaciones-rag-y-multi-ia`):** Firmar localmente e instalar el APK para probar captura Nequi (y visor de Diagnóstico en Ajustes), Rappi promos vs RappiCard/RappiCuenta, montos (`$5800` / `$5.800`), pestaña **Spam (5 días)** (Confirmar spam / A Pendientes / Corregir), ventana cruzada 5 min, `CorrectionDialog` sin NU por defecto, Multi-IA y Gemma local con `LocalGemmaCoordinator` antes de fusionar a `main`.
3. [ ] **Fase 2 (`wt-f2-archive`):** Implementar/finalizar `ArchiveService` + `DataManagementService` v2 + suite de pruebas en Docker.
4. [ ] **Fase 3 (requiere aprobación explícita):** Hooks mínimos en `credit_card_calculator.dart` y `transaction_service.dart` + selector de años archivados en `Statistics`.
5. [ ] `git push` a `origin/main` (solo con autorización explícita del usuario).
