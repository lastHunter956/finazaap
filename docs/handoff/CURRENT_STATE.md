# Estado Actual del Proyecto (`docs/handoff/CURRENT_STATE.md`)

> **Última actualización:** 2026-11-14 (Fase 1 de `ui-temas-y-asistente` completada en `integration/ui-temas-y-asistente`; pendiente de validación visual del usuario antes de Fase 2 y sin merge a `main`)  
> **Nota:** Tratar este documento como contexto previo, no como evidencia definitiva. Verificar `git status`, ramas, worktrees y Docker antes de actuar.

---

## 1. Estado Verificado del Repositorio y Entorno

- **Rama actual:** `integration/ui-temas-y-asistente` (consolidada desde `agent/ui/fase-1-tokens-contraste`, commit `35d9200`; **sin merge a `main`** hasta validación visual del usuario).
- **Estado de `main`:** `main` permanece en `165c1c1` (adelantada `34` commits respecto a `origin/main`, sin `git push`). Tag de seguridad previo: `pre-sprint-2-main` -> `2369699`.
- **Fase 1 (`ui-temas-y-asistente`) completada y en espera de validación visual:**
  - `lib/themes/app_theme_data.dart`: tokens de contraste WCAG 2.1 AA/AAA aplicados a `_diurno` (`#EEF2F8` / `#FFFFFF` / `#0B132B` / `#0062CC`) y `_dia` (`#F4EFE6` / `#FFFDF9` / `#1C1917` / `#0F766E`); paleta oficial Dracula aplicada a `_nocturno` (`#282A36` / `#313442` / `#44475A` / `#F8F8F2` / `#6272A4` / `#BD93F9` / `#8BE9FD` / `#50FA7B` / `#FFB86C` / `#FF5555`, más `AppTheme.draculaPink = #FF79C6`); `_defaultDark` intacto sin modificaciones; `onSecondary`/`onError` adaptativos en `buildThemeData`.
  - Colores hardcodeados corregidos sin añadir glass/blur ni cambiar estructura en `lib/widgets/total_balance_widget.dart`, `lib/widgets/custom_pill_bottom_nav_bar.dart`, `lib/Screens/settings_screen.dart` y `lib/Screens/statistics.dart`.
  - Artefactos Spec Kit en `.specify/ui-temas-y-asistente/{spec.md,plan.md,tasks.md}` y suite `test/themes/app_theme_contrast_test.dart`.
  - **Pendiente tras validación visual de Fase 1:** Fase 2 (rediseño de `AiChatScreen`) y Fase 3 (Liquid Glass moderado en `Diurno` solo para barra inferior y composer del chat).
- **Worktrees activos:** únicamente el worktree principal (`/Volumes/ADATA SD620/Programacion 7.0/moneo/finazaap`). Los 4 worktrees huérfanos de subagentes de Sprint 1 y las ramas auxiliares/integración previas ya fueron eliminados; sin worktrees huérfanos en Antigravity.
- **Commit de configuración de hooks y `.gitignore`:** `b45b31a` (`chore(security): configure fail-closed hooks, SessionStart handoff and gitignore rules`).
- **Política vigente para el futuro (`AGENTS.md` y `docs/handoff/DECISIONS.md`):**
  - Cada chat/agente trabaja en `agent/<nombre>/<tarea>` (con su propio `git worktree` si hay paralelismo) y consolida en **UNA** sola rama de integración por funcionalidad o sprint (`integration/<funcionalidad-o-sprint>`).
  - La rama de integración recibe `dart analyze` y `flutter test -j 1` en Docker y **permanece hasta que el usuario valide la funcionalidad en la aplicación** (prohibido eliminarla antes salvo orden explícita).
  - Solo tras la validación humana se hace merge a `main`, se re-ejecutan análisis y pruebas en `main`, y entonces se eliminan la rama de integración, las ramas `agent/*` y `subagent-*` contenidas y los worktrees limpios. `git push` e instalación en el teléfono requieren aprobación explícita.
- **Estado de integración de notificaciones reales (Sprint 2):** **El merge a `main` ya ocurrió, pero la integración NO está completamente validada — validada solo parcialmente en dispositivo físico (`Samsung SM_S721B`, serial `R5CY21GE9YY`).**
  - **Validado realmente en teléfono:** **Únicamente transferencia real** (notificación capturada e ingresada a la bandeja de pendientes, confirmada por el usuario, y saldo actualizado correctamente una sola vez).
  - **Validación ampliada pendiente para una sesión futura (no completada; no declarar validada toda la integración):** gastos reales, ingresos reales, transferencia entre cuentas propias, notificaciones duplicadas/actualizadas, confirmación repetida/reinicio, descarte sin mutación contable, apps no seleccionadas, notificaciones ambiguas, URLs no accionables y recuperación ante *force stop*/reinicio.
- **Mejoras implementadas en `agent/notifications/ux-y-optimizacion` (`2d803ae`):**
  - Nativo Android: `MoneoNotificationListenerService.kt` (`isListenerConnected`, `ensureServiceBound`/`requestRebind`, TTL de 7 días y tope de 200 eventos en `moneo_notif_queue.json`) y `MainActivity.kt` (`getListenerDiagnostics`, `openBatteryOptimizationSettings`, caché de apps instaladas con TTL de 5 min).
  - Pipeline y servicios Dart: `BankWhitelistService` y `AndroidNotificationSource` exponen `getListenerDiagnostics`; `NotificationPipelineService` procesa eventos en cola FIFO secuencial con caché de cuentas de 5 s.
  - UX: `SettingsScreen` refresca estado/diagnóstico al volver de Ajustes (`resumed`), guía exención de batería y resincroniza al restablecer; `Home` muestra botón AppBar con badge y banner directo a pendientes; `CustomPillBottomNavBar` muestra punto indicador en Ajustes.
  - APK debug instalado y probado por el usuario en `R5CY21GE9YY` (`/tmp/finazaap_debug_build/build/app/outputs/flutter-apk/app-debug.apk`): `SHA-256: 662cc1f50d848a79b54a88634aecc575fa1a2064961a7158d24f62ea3df885bf`, firma Android Debug `SHA-256: 1103fe225bd22694fb0ffc2e3d94ecd1cbb8f5a27712167b1eccab3a1f679e61`, `applicationId: com.example.finazaap`, `versionCode: 1`, `versionName: 1.0.0`.
- **Ramas observadas en el repositorio:**
  - `main` (`165c1c1`, adelantada `34` commits respecto a `origin/main`, sin `push`)
  - `agent/ui/fase-1-tokens-contraste` (rama de trabajo de Fase 1)
  - `integration/ui-temas-y-asistente` (rama de integración activa; **permanece hasta validación visual del usuario**, prohibido eliminar o fusionar a `main` antes)
- **Docker (`flutter-env` / `finazaap-flutter`):** Contenedor activo. Validación de Fase 1 en Docker: `dart analyze lib/themes/ test/themes/` con 0 issues, `dart analyze` global sin errores (solo warnings/infos preexistentes en archivos heredados) y `flutter test -j 1` **99/99 pasaron** (incluyendo 5 pruebas nuevas de contraste/Dracula).

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
- **Decisión explícita del usuario para `git push`** cuando desee publicar `main` hacia `origin/main` (actualmente `main` está adelantada `34` commits locales).
- Ejecución E2E Maestro en emulador/dispositivo físico (`.maestro/sprint_1_notificaciones.yaml`), actualmente pendiente de dispositivo/JRE.
