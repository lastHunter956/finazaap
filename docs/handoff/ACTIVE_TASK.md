# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `agent/claude/notificaciones-ia-y-spam` (implementada y validada en Docker `170/170`; pendiente consolidación vía merge en `integration/notificaciones-rag-y-multi-ia` y validación humana en dispositivo antes de fusionar a `main`)
> **Worktrees activos paralelos no relacionados:** `wt-f2-archive` (`agent/perf/archive-service-y-backup-v2`) y `wt-maestro-agentic` (`agent/maestro/configuracion-agentica`).

## Pendientes reales
1. [ ] **Consolidar `agent/claude/notificaciones-ia-y-spam` → `integration/notificaciones-rag-y-multi-ia`** (requiere aprobación de `git merge`) y recompilar APK `prod` para validación humana.
2. [ ] **Validación humana en Android (`integration/notificaciones-rag-y-multi-ia`):** Probar captura Nequi (y visor de Diagnóstico en Ajustes), Rappi promos vs RappiCard/RappiCuenta, montos (`$5800` / `$5.800`), pestaña **Spam (5 días)** (Confirmar spam / A Pendientes / Corregir), ventana cruzada 5 min, `CorrectionDialog` sin NU por defecto, Multi-IA y Gemma local con `LocalGemmaCoordinator` antes de fusionar a `main`.
3. [ ] **Fase 2 (`wt-f2-archive`):** Implementar/finalizar `ArchiveService` + `DataManagementService` v2 + suite de pruebas en Docker.
4. [ ] **Fase 3 (requiere aprobación explícita):** Hooks mínimos en `credit_card_calculator.dart` y `transaction_service.dart` + selector de años archivados en `Statistics`.
5. [ ] `git push` a `origin/main` (solo con autorización explícita del usuario).
