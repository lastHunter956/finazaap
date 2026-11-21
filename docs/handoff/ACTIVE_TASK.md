# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `main` (con `notificaciones-rag-y-multi-ia`, `notificaciones-ia-spam-y-lotes` y `ui-pulido-y-fluidez` fusionados vía `--ff-only`, auditados sin secretos y validados **378/378** en Docker; ramas/worktrees fusionados limpiados)
> **Worktrees activos paralelos no relacionados:** `wt-f2-archive` (`agent/perf/archive-service-y-backup-v2`) y `wt-maestro-agentic` (`agent/maestro/configuracion-agentica`).

## Pendientes reales
1. [x] **Auditoría de secretos, limpieza de `*.litertlm`/`*.hive` en `origin/main..main`, merge `--ff-only` a `main` y `git push origin main`.**
2. [ ] **Re-verificación post-merge y limpieza de ramas temporales en `main`:** Cuando Docker Desktop vuelva a estar activo, ejecutar `dart analyze` + `flutter test --no-pub -j 1` en `main` y eliminar las ramas ya integradas (`integration/*`, `agent/ui/*`, `agent/claude/notificaciones-ia-y-spam`) y los 4 worktrees temporales de subagentes.
3. [ ] **Fase 2 (`wt-f2-archive`):** Implementar/finalizar `ArchiveService` + `DataManagementService` v2 + suite de pruebas en Docker.
4. [ ] **Fase 3 (requiere aprobación explícita):** Hooks mínimos en `credit_card_calculator.dart` y `transaction_service.dart` + selector de años archivados en `Statistics`.
