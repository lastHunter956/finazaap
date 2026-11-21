# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `integration/ui-pulido-y-fluidez` @ `9622a71` (construida sobre `integration/notificaciones-rag-y-multi-ia` @ `21ece12`, validada en Docker **378/378**, APK `prod` release limpio compilado y listo para firma local + validación humana en Android antes de fusionar a `main`)
> **Worktrees activos paralelos no relacionados:** `wt-f2-archive` (`agent/perf/archive-service-y-backup-v2`) y `wt-maestro-agentic` (`agent/maestro/configuracion-agentica`).

## Pendientes reales
1. [x] **Consolidar `notificaciones-ia-spam-y-lotes` → `integration/notificaciones-rag-y-multi-ia`** (`2e540b8` / `21ece12`).
2. [x] **Orquestar e integrar `ui-pulido-y-fluidez` (4 subagentes `agent/ui/*`) → `integration/ui-pulido-y-fluidez`** (`9622a71`), validar suite completa (`378/378`) y compilar APK `prod` release limpio (`7f08ea6890550f87863ea52518fccb6e398f8e5c593d1ed81885ea6fa1119c0d`, `libapp.so`: `eb0ad2fbbddd7ba0d9e958b26dd201a479aad2d95d90c6c138cddd4a4d1f5b5b`).
3. [ ] **Validación humana en Android (`integration/ui-pulido-y-fluidez`):** Firmar localmente e instalar el APK para validar tanto el **pulido visual y fluidez** (nuevo `Home`, arco animado, Bottom Sheets sin blur lag, transiciones suaves, `Ajustes` y `Chat` sin `GoogleFonts`) como las **notificaciones bancarias** (Nequi + Diagnóstico de captura, Rappi promos vs RappiCard/RappiCuenta, montos `$5800`, Spam 5 días 0-IA, ventana cruzada 5 min, Multi-IA y Gemma local) antes de fusionar a `main`.
3. [ ] **Fase 2 (`wt-f2-archive`):** Implementar/finalizar `ArchiveService` + `DataManagementService` v2 + suite de pruebas en Docker.
4. [ ] **Fase 3 (requiere aprobación explícita):** Hooks mínimos en `credit_card_calculator.dart` y `transaction_service.dart` + selector de años archivados en `Statistics`.
5. [ ] `git push` a `origin/main` (solo con autorización explícita del usuario).
