# Estado Actual del Proyecto (`docs/handoff/CURRENT_STATE.md`)

> **Última actualización:** 2026-11-13 (creada rama `integration/sprint-2-notificaciones-reales` en `38b4a5d`; `main` intacta en `2369699`)  
> **Nota:** Tratar este documento como contexto previo, no como evidencia definitiva. Verificar `git status`, ramas, worktrees y Docker antes de actuar.

---

## 1. Estado Verificado del Repositorio y Entorno

- **Rama actual:** `agent/notifications/ux-y-optimizacion` (sobre `agent/config/contexto-y-seguridad` `378ed92` / `integration/notificaciones-reales` `0ac3c1c`).
- **Rama de integración Sprint 2:** `integration/sprint-2-notificaciones-reales` creada explícitamente en **`38b4a5d`** para consolidar el trabajo actual (`2d803ae` + handoff de validación parcial `38b4a5d`). **No se ha hecho merge a `main` ni `push`.**
- **Commit de configuración de hooks y `.gitignore`:** `b45b31a` (`chore(security): configure fail-closed hooks, SessionStart handoff and gitignore rules`).
- **Estado de integración de notificaciones reales (Sprint 2):** **Implementada y validada parcialmente por el usuario en dispositivo físico (`Samsung SM_S721B`, serial `R5CY21GE9YY`).**
  - **Validado realmente en teléfono:** **Transferencia real** (notificación capturada e ingresada a la bandeja de pendientes, confirmada por el usuario, y saldo actualizado correctamente una sola vez).
  - **Validación ampliada pendiente para una sesión futura (no completada; no declarar validada toda la integración):** gastos reales, ingresos reales, transferencia entre cuentas propias, notificaciones duplicadas/actualizadas, confirmación repetida/reinicio, descarte sin mutación contable, apps no seleccionadas, notificaciones ambiguas, URLs no accionables y recuperación ante *force stop*/reinicio.
- **Mejoras implementadas en `agent/notifications/ux-y-optimizacion` (`2d803ae`):**
  - Nativo Android: `MoneoNotificationListenerService.kt` (`isListenerConnected`, `ensureServiceBound`/`requestRebind`, TTL de 7 días y tope de 200 eventos en `moneo_notif_queue.json`) y `MainActivity.kt` (`getListenerDiagnostics`, `openBatteryOptimizationSettings`, caché de apps instaladas con TTL de 5 min).
  - Pipeline y servicios Dart: `BankWhitelistService` y `AndroidNotificationSource` exponen `getListenerDiagnostics`; `NotificationPipelineService` procesa eventos en cola FIFO secuencial con caché de cuentas de 5 s.
  - UX: `SettingsScreen` refresca estado/diagnóstico al volver de Ajustes (`resumed`), guía exención de batería y resincroniza al restablecer; `Home` muestra botón AppBar con badge y banner directo a pendientes; `CustomPillBottomNavBar` muestra punto indicador en Ajustes.
  - APK debug instalado y probado por el usuario en `R5CY21GE9YY` (`/tmp/finazaap_debug_build/build/app/outputs/flutter-apk/app-debug.apk`): `SHA-256: 662cc1f50d848a79b54a88634aecc575fa1a2064961a7158d24f62ea3df885bf`, firma Android Debug `SHA-256: 1103fe225bd22694fb0ffc2e3d94ecd1cbb8f5a27712167b1eccab3a1f679e61`, `applicationId: com.example.finazaap`, `versionCode: 1`, `versionName: 1.0.0`.
- **Ramas observadas en el repositorio:**
  - `main` (`2369699`, intacta; sin commits ni merges aplicados)
  - `integration/sprint-1` (`4514c12`)
  - `integration/notificaciones-reales` (`0ac3c1c`)
  - `integration/sprint-2-notificaciones-reales` (`38b4a5d`)
  - `agent/review/sprint-1-visual-demo` (`2096cf9`)
  - `chore/agy-audit` (`2369699`)
  - Ramas en worktrees activos de subagentes (`~/.agys/profiles/karoll/.gemini/antigravity-cli/worktrees/20c47763-743f-4efd-80c2-87004fe489ac/`):
    - `agent/classifier/clasificacion` (`9ae5001`)
    - `agent/parser/t01-domain-models` (`3566d32`)
    - `agent/feedback/bandeja-pendientes` (`7505f2d`)
    - `agent/parser/notificaciones` (`b4c4de4`)
- **Docker (`flutter-env` / `finazaap-flutter`):** Contenedor activo. Última verificación tras crear `integration/sprint-2-notificaciones-reales`: `dart analyze lib/features/notifications/ test/features/notifications/` (`No issues found!`, `0`) y `flutter test -j 1 test/` (`94/94` pasaron: `90` en `test/features/notifications/` + `4` en `test/widget_test.dart` y `test/ai_chat_service_test.dart`). Validación E2E de hooks en conversación limpia `524dbf94-a0d3-4c0a-87e4-c34c214650f4` completada con éxito.

---

## 2. Configuración Aplicada y Portabilidad

### Portable en el repositorio (versionado en Git)
- `AGENTS.md`: Punto de entrada corto con arranque obligatorio de handoff, reglas operativas esenciales, comandos Docker, archivos protegidos, flujo `spec -> plan -> tasks -> implement -> test` e índice documental.
- `.agents/hooks.json` (resuelve raíz vía `git rev-parse --show-toplevel` para raíz del repo, `.agents/` y worktrees):
  - `SessionStart` → `.agents/hooks/session_start_handoff.sh` (inyecta `ARRANQUE OBLIGATORIO (Moneo)`).
  - `PreToolUse` → `.agents/hooks/security_guard.py` (*fail-closed* sobre `read_file|view_file|write_file|write_to_file|edit_file|replace_file_content|multi_replace_file_content|run_command|shell_exec`).
  - `PreToolUse` → `.agents/hooks/check_protected_files.py` (*fail-closed* para archivos protegidos).
  - `PostToolUse` → `.agents/hooks/post_edit_analyze.sh` (`docker-compose exec -T flutter-env dart analyze` solo al editar `.dart`, `pubspec.yaml` o `analysis_options.yaml`).
  - `Stop` → `.agents/hooks/pre_stop_test.sh` (`docker-compose exec -T flutter-env flutter test -j 1` cuando `fullyIdle=true` y `continuationActive=false`; falla con `decision: "continue"` si `flutter-env` no está activo).
- `.gitignore`: Excluye `.env`/`.env.*` (conservando `.env.example`, `.env.template`, `.env.sample`), claves/certificados/keystores/credenciales, cajas Hive/DBs locales reales, estado local del agente, handoffs privados (`*.private.md`, `docs/handoff/.local/`) y cobertura (`coverage/`, `*.lcov`), manteniendo `.agents/skills/`, `.agents/rules/`, `.agents/hooks/` y fixtures sintéticos.

### Dependiente del perfil local (fuera del repositorio)
- `/Users/jesusmartinez/.agys/profiles/karoll/.gemini/antigravity-cli/settings.json`: Contiene el bloque secundario `"permissions"` con reglas `command(...)` (`deny` para `adb uninstall*`, `adb shell pm clear*`, `adb shell am force-stop*`, `adb install -d*`; `ask` para `adb install*`, `flutter install*`, `git push*`, `git merge*`, `git rebase*`; `allow` para `docker-compose *`, `docker exec finazaap-flutter *`, `git status*`, `git diff*`, `git log*`, `git branch*`, `git worktree*`), conservando `model`, `statusLine` y `trustedWorkspaces`. En otro equipo/perfil se replica manualmente o vía `/permissions`; la capa principal sigue siendo `.agents/hooks.json`.

---

## 3. Mapa Real de Restricciones vs. Instrucciones

- **Protección técnica real (Hooks en `.agents/hooks.json` + `permissions` en `settings.json`):**
  - `deny` para lectura/escritura en `.env`, `.env.*` (salvo `.env.example`, `.env.template`, `.env.sample`), claves, certificados, keystores, credenciales y escritura directa en `.git/`.
  - `deny` para `adb uninstall`, `adb shell pm clear`, `adb shell am force-stop`, `adb install -d` y borrado de datos de app.
  - `deny` para envío por red de secretos, notificaciones o datos financieros; `force_ask` en comandos de red que mencionen términos/rutas sensibles (sin bloquear `curl`/`wget` normales).
  - `force_ask` para `adb install` / `flutter install`, `git merge` / `rebase` / `push`, archivos protegidos (edición directa, shell o `build_runner`) y migraciones de esquema/datos.
  - Inyección automática de arranque (`SessionStart`) y gate de pruebas en `Stop`.
- **Dependiente de instrucciones en `AGENTS.md` (sin bloqueo técnico determinista):**
  - Orden exacto de lectura de handoff y actualización al final de la sesión.
  - No instalar herramientas en el host fuera de comandos interceptados.
  - Distinción real vs demo vs stub y política de no tratar una URL por sí sola como evidencia de fraude en lógica de negocio.
  - No redactar secretos ni contenido íntegro de notificaciones reales en documentos/logs cuando no provengan de archivos bloqueados.

---

## 4. Próximos Pasos Pendientes

- **Validación manual ampliada en sesión futura** sobre dispositivo físico (`R5CY21GE9YY`), junto con otras mejoras pendientes: gastos reales, ingresos reales, transferencia entre cuentas propias, duplicados/actualizaciones, confirmación repetida/reinicio, descarte sin mutación contable, apps no seleccionadas, notificaciones ambiguas, URLs no accionables y recuperación ante *force stop* / reapertura.
- **Aprobación final explícita del usuario** antes de realizar cualquier merge hacia `main` (o eventual actualización de `integration/sprint-2-notificaciones-reales` y `push`).
- Ejecución E2E Maestro en emulador/dispositivo físico (`.maestro/sprint_1_notificaciones.yaml`), actualmente pendiente de dispositivo/JRE.
