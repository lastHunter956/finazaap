# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `main` (Fase 1 consolidada en `3361e83`, `277/277` tests OK en Docker)
> **Estado:** Iniciando **Fase 2 — Preparación de Archivado Frío Seguro** en worktree aislado `wt-f2-archive` (`agent/perf/archive-service-y-backup-v2`), sin tocar archivos protegidos.

## Pendientes reales
1. [ ] **Fase 2:** Implementar `ArchiveService` (journal idempotente, `carryForwardDebt`, exclusión de cuotas activas, rollback) + `DataManagementService` v2 (export/import completo y `deleteAllData()`) + suite de pruebas unitarias/invariancia en Docker.
2. [ ] **Fase 3 (requiere aprobación explícita):** Hooks mínimos en `credit_card_calculator.dart` y `transaction_service.dart` + selector de años archivados en `Statistics`.
3. [ ] `git push` a `origin/main` (solo con autorización explícita del usuario).
