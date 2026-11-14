# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama activa (única en el repositorio):** `main` (tag de seguridad previo: `pre-sprint-2-main` en `2369699`; adelantada `33` commits vs `origin/main`, sin `push`)  
> **Estado:** Todo el trabajo de Sprint 1, Sprint 2, hooks de seguridad, handoff y política de integración autónoma está consolidado en `main`. Integración real de notificaciones **validada parcialmente** en el teléfono (`R5CY21GE9YY`: transferencia real confirmada correctamente); validación ampliada pendiente para una sesión futura.

## Objetivo
Mantener `main` consolidada y limpia (única rama y único worktree principal), con la política de integración autónoma aplicada y sin worktrees huérfanos en Antigravity, dejando pendiente únicamente la validación ampliada en teléfono y la autorización de `git push`.

## Plan Activo
1. [x] **Fases 1 a 3 (`2d803ae`):** Rebind nativo Android, diagnóstico de conexión/batería, TTL/tope en cola nativa, refresco en `resumed`, banner/badges de pendientes en `Home`/navegación y cola secuencial FIFO con caché de cuentas.
2. [x] **Instalación en `R5CY21GE9YY`:** APK debug actualizado *in-place* preservando datos (`SHA-256: 662cc1f50d848a79b54a88634aecc575fa1a2064961a7158d24f62ea3df885bf`).
3. [x] **Validación parcial del usuario en teléfono:** Transferencia real confirmada correctamente una sola vez.
4. [x] **Política de integración autónoma, consolidación en `main` y limpieza:** Tag `pre-sprint-2-main` en `2369699`, política guardada en `AGENTS.md` y `DECISIONS.md`, limpieza segura de 4 worktrees y 14+1 ramas con `git branch -d`, merge `--ff-only` a `main` y validación completa en Docker.
5. [ ] **Validación real ampliada (sesión futura, en teléfono por el usuario):** Gasto real, ingreso real, transferencia entre cuentas propias, notificación duplicada/actualizada, confirmación repetida y reinicio, descarte sin mutación contable, app no seleccionada, notificación ambigua, URL no accionable y *force stop* + reapertura, junto con mejoras posteriores.
6. [ ] **Publicación remota (`git push`):** Pendiente de aprobación explícita del usuario (`main` adelantada `33` commits locales respecto a `origin/main`).

## Criterio de Término
- Solo el caso de **transferencia real** consta como validado en teléfono; la validación ampliada permanece explícitamente pendiente.
- Repositorio local con únicamente la rama `main`, el worktree principal y el tag `pre-sprint-2-main` (`2369699`), sin worktrees huérfanos.
- `dart analyze` (en notificaciones) y `flutter test -j 1 test/` en verde sobre `main`, sin haber ejecutado `git push`.
