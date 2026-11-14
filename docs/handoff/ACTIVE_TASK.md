# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama:** `agent/notifications/ux-y-optimizacion` (sobre `agent/config/contexto-y-seguridad` `378ed92` / `integration/notificaciones-reales` `0ac3c1c`)  
> **Estado:** Fases 1 a 3 implementadas y verificadas en Docker (`94/94` tests); pendiente autorización para instalar APK actualizado en `R5CY21GE9YY` y validación manual

## Objetivo
Mejorar el ciclo de vida real del `NotificationListenerService` en Android, la experiencia de usuario al configurar permisos y revisar movimientos pendientes, y el rendimiento/higiene del pipeline de notificaciones (Fases 1 a 3), sin modificar archivos protegidos ni `main`.

## Plan Activo
1. [x] **Fase 1:** Estado real `isListenerConnected`, `requestRebind` nativo en `MoneoNotificationListenerService.kt`, diagnóstico de batería y refresco automático en `SettingsScreen` al reanudar (`AppLifecycleState.resumed`).
2. [x] **Fase 2:** Botón con badge en `AppBar` y banner directo de pendientes en `Home`, además de indicador en `CustomPillBottomNavBar`.
3. [x] **Fase 3:** Caché de apps instaladas con TTL de 5 min en `MainActivity.kt`, cota de 200 eventos y TTL de 7 días en `moneo_notif_queue.json`, cola FIFO secuencial y caché de cuentas de 5 s en `NotificationPipelineService`.
4. [x] **Verificación Docker:** `dart analyze lib/features/notifications/ test/features/notifications/` (`No issues found!`), `flutter test -j 1 --timeout 60s test/` (`94/94` pasando) y build debug APK en `/tmp/finazaap_debug_build/build/app/outputs/flutter-apk/app-debug.apk`.
5. [ ] Instalación `adb -s R5CY21GE9YY install -r` previa autorización explícita del usuario y prueba manual con notificación bancaria real.

## Criterio de Término
- Análisis estático sin issues en `lib/features/notifications/` y `test/features/notifications/`, y `94/94` pruebas pasando en Docker tras los últimos cambios de código.
- Commit atómico en `agent/notifications/ux-y-optimizacion`, preservando `main` intacto.
- Validación en teléfono ejecutada y aprobada por el usuario sin borrar datos existentes.
