# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama activa (única en el repositorio):** `main` (tag de seguridad previo para rollback: `pre-sprint-2-main` en `2369699`; adelantada `34` commits vs `origin/main`, sin `push`)  
> **Estado:** El merge previo de Sprint 1 y Sprint 2 a `main` ya ocurrió antes de corregir la política (no se deshace; queda como punto de partida). La política ya fue corregida para futuros desarrollos: toda rama `integration/<funcionalidad-o-sprint>` deberá **permanecer hasta que el usuario valide en la app**. La integración de notificaciones **NO está completamente validada**: solo se validó una **transferencia real** en `R5CY21GE9YY` y la validación ampliada sigue pendiente.

## Objetivo
Mantener `main` estable y protegida como punto de partida actual (sin `git push`), aplicar en adelante el modelo de rama única `integration/<funcionalidad-o-sprint>` con permanencia hasta validación humana, y completar en sesión futura la validación ampliada en el teléfono.

## Plan Activo
1. [x] **Fases 1 a 3 (`2d803ae`):** Rebind nativo Android, diagnóstico de conexión/batería, TTL/tope en cola nativa, refresco en `resumed`, banner/badges de pendientes en `Home`/navegación y cola secuencial FIFO con caché de cuentas.
2. [x] **Instalación en `R5CY21GE9YY`:** APK debug actualizado *in-place* preservando datos (`SHA-256: 662cc1f50d848a79b54a88634aecc575fa1a2064961a7158d24f62ea3df885bf`).
3. [x] **Validación parcial del usuario en teléfono:** Únicamente transferencia real confirmada correctamente una sola vez.
4. [x] **Merge previo a `main`, limpieza y corrección de política:** `main` consolidada con tag `pre-sprint-2-main` (`2369699`); política corregida en `AGENTS.md` y `docs/handoff/DECISIONS.md` para que futuras ramas `integration/<funcionalidad-o-sprint>` permanezcan hasta validación humana antes del merge a `main`.
5. [ ] **Validación real ampliada (sesión futura, en teléfono por el usuario):** Gasto real, ingreso real, transferencia entre cuentas propias, notificación duplicada/actualizada, confirmación repetida y reinicio, descarte sin mutación contable, app no seleccionada, notificación ambigua, URL no accionable y *force stop* + reapertura, junto con mejoras posteriores.
6. [ ] **Publicación remota (`git push`):** Pendiente de aprobación explícita del usuario (`main` adelantada vs `origin/main`).

## Criterio de Término
- Solo el caso de **transferencia real** consta como validado en teléfono; no se declara completamente validada la integración y la validación ampliada sigue pendiente.
- La política en `AGENTS.md` y `docs/handoff/DECISIONS.md` exige que `integration/<funcionalidad-o-sprint>` permanezca hasta validación humana antes de fusionar a `main` y eliminar ramas/worktrees.
- Repositorio local limpio en `main`, sin worktrees huérfanos ni `git push`.
