# Estado Actual del Proyecto (`docs/handoff/CURRENT_STATE.md`)

> **Última actualización:** 2026-11-13 (todo el trabajo consolidado en `main`; política de integración autónoma aplicada; sin `git push`)  
> **Nota:** Tratar este documento como contexto previo, no como evidencia definitiva. Verificar `git status`, ramas, worktrees y Docker antes de actuar.

---

## 1. Estado Verificado del Repositorio y Entorno

- **Rama actual:** `main` (única rama local en el repositorio tras consolidar Sprint 1, Sprint 2, hooks de seguridad, handoff y la política de integración autónoma).
- **Estado frente a remoto:** `main` está adelantada respecto a `origin/main` (`33` commits totales —`8+` commits— incluyendo la historia de Sprint 1, Sprint 2, seguridad y documentación). **No se ha hecho `git push`.**
- **Tag de seguridad pre-merge:** `pre-sprint-2-main` -> `2369699`.
- **Worktrees activos:** únicamente el worktree principal (`/Volumes/ADATA SD620/Programacion 7.0/moneo/finazaap`). Los 4 worktrees huérfanos de subagentes de Sprint 1 y las 14 ramas auxiliares/integración fueron eliminados de forma segura tras comprobar `git merge-base --is-ancestor` y estado limpio; sin worktrees huérfanos en Antigravity.
- **Commit de configuración de hooks y `.gitignore`:** `b45b31a` (`chore(security): configure fail-closed hooks, SessionStart handoff and gitignore rules`).
- **Política aplicada:** Política de Integración Autónoma activa en `AGENTS.md` y `docs/handoff/DECISIONS.md` (merge local automático a `main` y limpieza de ramas/worktrees tras análisis y pruebas verdes en Docker; `git push`, instalaciones/comandos destructivos en teléfono, secretos, migraciones destructivas y acciones irreversibles externas requieren aprobación explícita).
- **Estado de integración de notificaciones reales (Sprint 2):** **Implementada y validada parcialmente por el usuario en dispositivo físico (`Samsung SM_S721B`, serial `R5CY21GE9YY`).**
  - **Validado realmente en teléfono:** **Transferencia real** (notificación capturada e ingresada a la bandeja de pendientes, confirmada por el usuario, y saldo actualizado correctamente una sola vez).
  - **Validación ampliada pendiente para una sesión futura (no completada; no declarar validada toda la integración):** gastos reales, ingresos reales, transferencia entre cuentas propias, notificaciones duplicadas/actualizadas, confirmación repetida/reinicio, descarte sin mutación contable, apps no seleccionadas, notificaciones ambiguas, URLs no accionables y recuperación ante *force stop*/reinicio.
- **Mejoras implementadas en `agent/notifications/ux-y-optimizacion` (`2d803ae`):**
  - Nativo Android: `MoneoNotificationListenerService.kt` (`isListenerConnected`, `ensureServiceBound`/`requestRebind`, TTL de 7 días y tope de 200 eventos en `moneo_notif_queue.json`) y `MainActivity.kt` (`getListenerDiagnostics`, `openBatteryOptimizationSettings`, caché de apps instaladas con TTL de 5 min).
  - Pipeline y servicios Dart: `BankWhitelistService` y `AndroidNotificationSource` exponen `getListenerDiagnostics`; `NotificationPipelineService` procesa eventos en cola FIFO secuencial con caché de cuentas de 5 s.
  - UX: `SettingsScreen` refresca estado/diagnóstico al volver de Ajustes (`resumed`), guía exención de batería y resincroniza al restablecer; `Home` muestra botón AppBar con badge y banner directo a pendientes; `CustomPillBottomNavBar` muestra punto indicador en Ajustes.
  - APK debug instalado y probado por el usuario en `R5CY21GE9YY` (`/tmp/finazaap_debug_build/build/app/outputs/flutter-apk/app-debug.apk`): `SHA-256: 662cc1f50d848a79b54a88634aecc575fa1a2064961a7158d24f62ea3df885bf`, firma Android Debug `SHA-256: 1103fe225bd22694fb0ffc2e3d94ecd1cbb8f5a27712167b1eccab3a1f679e61`, `applicationId: com.example.finazaap`, `versionCode: 1`, `versionName: 1.0.0`.
- **Ramas observadas en el repositorio:**
  - `main` (única rama; contiene todo Sprint 1, Sprint 2, hooks de seguridad, handoff y política de integración autónoma; adelantada `33` commits respecto a `origin/main`, sin `push`)
- **Docker (`flutter-env` / `finazaap-flutter`):** Contenedor activo. Validación obligatoria en `main` tras el merge (`dart analyze lib/features/notifications/ test/features/notifications/` sin issues y `flutter test -j 1 test/` 94/94 pasaron). Validación E2E de hooks en conversación limpia `524dbf94-a0d3-4c0a-87e4-c34c214650f4` completada con éxito.

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
- **Decisión explícita del usuario para `git push`** cuando desee publicar `main` hacia `origin/main` (actualmente `main` está adelantada `33` commits locales).
- Ejecución E2E Maestro en emulador/dispositivo físico (`.maestro/sprint_1_notificaciones.yaml`), actualmente pendiente de dispositivo/JRE.
