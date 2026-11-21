# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `main` (con `notificaciones-rag-y-multi-ia`, `notificaciones-ia-spam-y-lotes` y `ui-pulido-y-fluidez` fusionados vía `--ff-only`, auditados sin secretos y validados **378/378** en Docker; ramas/worktrees fusionados limpiados)
> **Worktrees activos paralelos no relacionados:** `wt-f2-archive` (`agent/perf/archive-service-y-backup-v2`) y `wt-maestro-agentic` (`agent/maestro/configuracion-agentica`).

## Pendientes reales
1. [x] **Auditoría de secretos y merge `--ff-only` a `main`** + re-validación en Docker + limpieza de ramas/worktrees integrados.
2. [ ] **Desbloquear y ejecutar `git push origin main`:** Decidir con el usuario cómo tratar los archivos `2.4 GB` × 2 (`assets/models/gemma.litertlm`, `web/models/gemma.litertlm` en `288de81`) y `0 B` (`data.hive`, `responsibilities.hive` en `52048d8`) que impiden subir a GitHub (> 100 MB).
3. [ ] **Fase 2 (`wt-f2-archive`):** Implementar/finalizar `ArchiveService` + `DataManagementService` v2 + suite de pruebas en Docker.
4. [ ] **Fase 3 (requiere aprobación explícita):** Hooks mínimos en `credit_card_calculator.dart` y `transaction_service.dart` + selector de años archivados en `Statistics`.
