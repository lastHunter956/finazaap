# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama:** `agent/notifications/ux-y-optimizacion` (sobre `agent/config/contexto-y-seguridad` `378ed92` / `integration/notificaciones-reales` `0ac3c1c`)  
> **Estado:** Integración de notificaciones reales **implementada y validada parcialmente** en el teléfono (`R5CY21GE9YY`) — validada transferencia real; faltan gastos, ingresos, duplicados, ambigüedad, descarte y recuperación

## Objetivo
Consolidar la validación parcial en teléfono, auditar la rama frente a su base (`2096cf9` / `integration/sprint-1`), verificar la suite completa en Docker y preparar la propuesta de rama de integración (`integration/sprint-2-notificaciones-reales`) sin modificar `main`.

## Plan Activo
1. [x] **Fases 1 a 3 (`2d803ae`):** Rebind nativo Android, diagnóstico de conexión/batería, TTL/tope en cola nativa, refresco en `resumed`, banner/badges de pendientes en `Home`/navegación y cola secuencial FIFO con caché de cuentas.
2. [x] **Instalación en `R5CY21GE9YY`:** APK debug actualizado *in-place* preservando datos (`SHA-256: 662cc1f50d848a79b54a88634aecc575fa1a2064961a7158d24f62ea3df885bf`).
3. [x] **Validación parcial del usuario en teléfono:** Transferencia real detectada en bandeja de pendientes, confirmada y reflejada correctamente una sola vez en el saldo.
4. [ ] **Validación real ampliada pendiente (en teléfono, por el usuario):** Gasto real, ingreso real, transferencia entre cuentas propias, notificación duplicada/actualizada, confirmación repetida y reinicio, descarte sin mutación contable, app no seleccionada, notificación ambigua, URL no accionable y *force stop* + reapertura.
5. [x] **Auditoría pre-integración y verificación Docker:** Revisión de diffs, archivos protegidos, secretos/binarios y suite `dart analyze` + `flutter test -j 1 test/`.
6. [ ] **Aprobación del usuario:** Creación de `integration/sprint-2-notificaciones-reales` y decisión posterior sobre `main`.

## Criterio de Término
- Solo el caso de **transferencia real** consta como validado en teléfono; los casos restantes figuran explícitamente pendientes.
- Ningún secreto, dato financiero real ni archivo binario no autorizado presente en los diffs.
- `main` permanece intacta sin commits ni merges.
