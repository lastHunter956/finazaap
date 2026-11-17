# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `main` (consolidado sprint `pulido-visual-web` tras validación en Docker y generación de APK; **sin `git push` ni `adb install` automáticos**)
> **Worktrees activos paralelos no relacionados:** `wt-f2-archive` (`agent/perf/archive-service-y-backup-v2`) y `wt-maestro-agentic` (`agent/maestro/configuracion-agentica`).

## Pendientes reales
1. [ ] **Validación física en Android (cuando el usuario apruebe `adb install`):** Instalar el APK generado desde `main` (ver ruta y SHA-256 reportados al usuario) y completar la matriz de validación de notificaciones reales en `R5CY21GE9YY`.
2. [ ] **Fase 2 (`wt-f2-archive`):** Implementar/finalizar `ArchiveService` + `DataManagementService` v2 + suite de pruebas en Docker.
3. [ ] **Fase 3 (requiere aprobación explícita):** Hooks mínimos en `credit_card_calculator.dart` y `transaction_service.dart` + selector de años archivados en `Statistics`.
4. [ ] `git push` a `origin/main` (solo con autorización explícita del usuario).
