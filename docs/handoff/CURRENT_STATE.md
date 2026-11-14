# Estado Actual del Proyecto (`docs/handoff/CURRENT_STATE.md`)

> **Última actualización:** 2026-11-14 (Cierre de lote autónomo en `agent/ui/t1-3c-daily-transactions-delete` @ `c43a3ea` con `164/164` tests en verde; ver detalle en `docs/audit/CONTINUITY_STATE.md`)  
> **Nota:** Tratar este documento como contexto previo, no como evidencia definitiva. Verificar `git status`, ramas, worktrees y Docker antes de actuar.

---

## 1. Estado Verificado del Repositorio y Entorno

- **Rama actual:** `agent/ui/t1-3c-daily-transactions-delete` (desde `05379fa`, rama con todas las correcciones acumuladas de Ola 1: `agent/ui/t1-1-account-item-dedup` @ `05379fa`; **sin `git push` ni `merge` a `main`**). `main` permanece en `bab211f`. Tag de seguridad previo: `pre-sprint-2-main` -> `2369699`.
- **Integración `ui-temas-y-asistente` aprobada y fusionada en `main`:**
  - `lib/themes/app_theme_data.dart`: contraste WCAG 2.1 AA (`>=4.5:1`) y AAA (`>=7.0:1`) verificado sobre las **3 superficies** (`primaryBackground`, `cardBackground`, `darkBackground`) en `_diurno`, `_dia` y `_nocturno` (Dracula oficial); `_defaultDark` 100% intacto sin modificaciones; re-exporta `lib/widgets/liquid_glass_surface.dart`.
  - **Navegación, FAB `+`, Scroll Clearance y Movimiento (`Diurno`)**: `lib/widgets/liquid_glass_surface.dart` (`MoneoLayoutMetrics`, `MoneoNavBarScope`, `MoneoSpringMotion` con `SpringSimulation(mass: 1.0, stiffness: 380.0, damping: 30.0)`, `MoneoPressableScale`, `LiquidGlassSurface`), `MainContainer` (`effectiveBottomClearance`), `CustomPillBottomNavBar` (cápsula proporcional con continuidad `SpringSimulation` en `Diurno`), `FloatingActionMenu` (`t.buttonBackground`/`t.buttonForeground` con contraste AA) y `TotalBalanceCard` (`MoneoPressableScale` discreto en segmentos `Diurno`).
  - **Conversación Editorial y Perfil Cognitivo (`lib/Screens/ai_chat_screen.dart`):** burbujas editoriales limpias sin bordes neón, sin sombras multicapa ni círculos/badges repetidos, ancho orgánico sin `Spacer()`, cero `BackdropFilter` en contenido, tarjetas estructuradas solo en sugerencias accionables (`INGRESO`/`GASTO`, `CurrencyHelper`, acciones integradas), y `Perfil Cognitivo` sin marcas de agua ni truncamientos `.substring(0, 12)` con salto adaptativo entre grilla 2×2 y columna según ancho (`< 380`) y `TextScaler` (`scale(14) > 16.5`).
  - **Encabezados Unificados y Clearance en 13 Pantallas (`lib/widgets/moneo_header_bar.dart`):** `MoneoHeaderBar` (`primaryTab`, `subScreen`, `form`) y `MoneoSegmentedControl` usando `TextStyle` nativo 100% offline, altura dinámica `preferredHeightFor` y `MoneoLayoutMetrics.scrollBottomPadding` aplicados en `Home`, `ResponsibilitiesScreen`, `CategoriesScreen`, `Statistics`, `SettingsScreen`, `PendingTransactionsScreen`, `SelectAccountScreen`, `AnnualProjectionScreen`, `AccountManagement`, `EditProfileScreen`, `AddScreen`, `AddExpenseScreen` y `TransferScreen`.
  - **Retiro de `"Bandeja de Notificaciones (Demo Dev)"`** (`settings_notifications_demo_tile`) en `lib/Screens/settings_screen.dart`.
  - **Suites de Prueba Separadas:** `test/themes/app_theme_contrast_test.dart` (tokens y WCAG 2.1 AA/AAA) y `test/widgets/ui_layout_and_navigation_test.dart` (`LiquidGlassSurface` + accesibilidad, no solapamiento `CustomPillBottomNavBar`/`FloatingActionMenu` en `360x640` con `TextScaler 1.35`, `AiChatScreen` chat/teclado/burbujas/`Perfil Cognitivo` y `MoneoHeaderBar`/`MoneoSegmentedControl`).
  - **Validación en Docker (`finazaap-flutter`):** `dart analyze` en archivos UI/temas/pruebas con `No issues found!`, `dart analyze --no-fatal-warnings lib/Screens/ lib/features/` con 0 errores y `flutter test --no-pub -j 1` **104/104 pasaron**.
- **Worktrees y ramas limpias:** únicamente existe el worktree principal (`/Volumes/ADATA SD620/Programacion 7.0/moneo/finazaap`) y la rama `main`; los worktrees paralelos, las ramas `agent/ui/*` y la rama `integration/ui-temas-y-asistente` ya fusionada fueron eliminados tras aprobar pruebas en `main`.
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
  - `main` (adelantada respecto a `origin/main`, sin `push`)
- **Docker (`flutter-env` / `finazaap-flutter`):** Contenedor activo. Validación completa en Docker sobre `main` (`dart analyze` + `flutter test --no-pub -j 1`). APK debug preparado desde `main` para revisión y aprobación explícita de `adb install` en el teléfono físico del usuario.

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
