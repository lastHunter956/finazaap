# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama de trabajo:** `agent/notifications/ux-y-optimizacion` (sobre `38b4a5d`)  
> **Rama de integración creada:** `integration/sprint-2-notificaciones-reales` -> `38b4a5d` (`main` intacta en `2369699`)  
> **Estado:** Integración real de notificaciones **implementada y parcialmente validada** en el teléfono (`R5CY21GE9YY`: transferencia real confirmada correctamente); validación ampliada pendiente para una sesión futura

## Objetivo
Consolidar el trabajo actual en `integration/sprint-2-notificaciones-reales` (apuntando a `38b4a5d`) sin modificar `main`, mantener documentado que solo la transferencia real ha sido validada en dispositivo físico y dejar lista la validación ampliada para una sesión futura.

## Plan Activo
1. [x] **Fases 1 a 3 (`2d803ae`):** Rebind nativo Android, diagnóstico de conexión/batería, TTL/tope en cola nativa, refresco en `resumed`, banner/badges de pendientes en `Home`/navegación y cola secuencial FIFO con caché de cuentas.
2. [x] **Instalación en `R5CY21GE9YY`:** APK debug actualizado *in-place* preservando datos (`SHA-256: 662cc1f50d848a79b54a88634aecc575fa1a2064961a7158d24f62ea3df885bf`).
3. [x] **Validación parcial del usuario en teléfono:** Transferencia real confirmada correctamente una sola vez.
4. [x] **Consolidación de rama (`integration/sprint-2-notificaciones-reales`):** Creada en `38b4a5d` con autorización explícita del usuario, verificada con `dart analyze` (`0` issues en notificaciones) y `flutter test -j 1 test/` (`94/94`), sin merge a `main` ni `push`.
5. [ ] **Validación real ampliada (sesión futura, en teléfono por el usuario):** Gasto real, ingreso real, transferencia entre cuentas propias, notificación duplicada/actualizada, confirmación repetida y reinicio, descarte sin mutación contable, app no seleccionada, notificación ambigua, URL no accionable y *force stop* + reapertura, junto con mejoras posteriores.
6. [ ] **Aprobación final del usuario para `main`:** Decisión pendiente hasta completar validaciones restantes.

## Criterio de Término
- Solo el caso de **transferencia real** consta como validado en teléfono; la validación ampliada permanece explícitamente pendiente.
- `integration/sprint-2-notificaciones-reales` creada en `38b4a5d` sin merge ni push.
- `main` permanece intacta en `2369699`.
