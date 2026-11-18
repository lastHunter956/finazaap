# Estado Actual del Proyecto (`docs/handoff/CURRENT_STATE.md`)

> **Última actualización:** 2026-11-18 (Rama de integración `integration/notificaciones-rag-y-multi-ia` @ `833a966` con fixes Multi-IA y APK `prod` recompilado listo para firma y validación humana; `main` sin cambios)
> **Nota:** Tratar este documento como contexto previo, no como evidencia definitiva. Verificar `git status`, ramas, worktrees y Docker antes de actuar.

---

## 1. Estado Verificado del Repositorio y Entorno

- **Rama actual:** `integration/notificaciones-rag-y-multi-ia` (pendiente de validación humana antes de fusionar a `main`; `main` permanece intacta en `0b8cd3a`).
- **Feature `notificaciones-rag-y-multi-ia` integrada desde 4 ramas de agentes en paralelo:**
  - **Mini-RAG en disco (`agent/rag/indice-semantico-y-patrones`):** `LearnedPattern` con `aliases`/`knownPackages` retrocompatibles, `CompactSimilarityIndex` (`posting lists` + ecuación híbrida BM25/Jaccard/Paquete/Confirmaciones `< 1 ms`), lectura perezosa por cabeceras en `LearnedPatternsService`, resolución semántica en Etapa 1 (`Score >= 0.88`) y `strategicNote` O(1) con `MonthlySummaryCache` en `TransactionClassifier`.
  - **Correlación Multi-App y Feedback Loop (`agent/dedup/correlacion-multi-app`):** anillo de movimientos confirmados 48 h (`notification_recent_movements`, tope 100), aprendizaje automático de `DedupRule` multi-app cuando se confirma/corrige 1 y se descartan duplicados en `< 30 min`, agrupación en 1 tarjeta con `strategicNote` de avisos agrupados y `warmUp()` en `NotificationPipelineService`.
  - **Router Multi-Proveedor y Carga Lazy (`agent/ai/router-multi-proveedor`):** `AiProviderConfigStore` (múltiples API Keys cifradas en `FlutterSecureStorage` + selector de **IA Principal**), `AiProviderRouter` (`OpenRouter` con `models` + `openrouter/free`, `NVIDIA NIM`, `OpenCode Zen`, `Google Gemini`, `OpenAI`) con rotación por `429`/`Retry-After`/`503`, `GemmaClassifierAdapter` y `AiChatService` enrutando a la IA Principal, y arranque *lazy* sin cargar `FlutterGemma` cuando se usa Cloud/Simulador + descarga de RAM tras 2 min de inactividad en Local.
  - **UI de Bandeja Agrupada y Ajustes Multi-IA (`agent/ui/bandeja-y-ajustes-ia`):** cápsula `strategicNote`, badge `"Agrupada (N avisos)"`, botón **Separar** y selección múltiple **Agrupar en 1** en `PendingTransactionsScreen`/`PendingTransactionCard`; gestor multi-API Key, selector de IA Principal, prueba de conexión / catálogo y opciones HuggingFace/Gemma 4 en `SettingsScreen` y `AiChatScreen`.
  - **Sin tocar archivos protegidos** (`transaction_service.dart`, `credit_card_calculator.dart`, `*.g.dart`, `build.gradle`, `AndroidManifest.xml`, `lib/core/security/*`).
- **Fixes Multi-IA posteriores en `integration/notificaciones-rag-y-multi-ia` (`32a9baf`, `833a966`) y APK `prod` recompilado:**
  - Límite de arreglo `models` en OpenRouter (`<= 3` ítems), `maxTokens: 512` en `testConnection` para modelos con `reasoning`, fallback automático a `openrouter/free` ante `HTTP 400/404/410` o `FormatException`, actualización de modelos vigentes de NVIDIA NIM / OpenRouter / OpenCode Zen (resolviendo `HTTP 410 Gone`), filtro de catálogo OpenAI + `max_completion_tokens` en `o1/o3/o4/gpt-5`, preservación del detalle `HTTP 429` y aviso CORS en Web.
  - Pruebas en Docker tras `833a966`: `dart analyze` limpio en archivos editados (`No issues found!`), `128/128` y `50/50` pruebas pasando en suites de router IA, ajustes y módulo de notificaciones (con HTTP mockeado vía `MockClient`).
  - Compilado `build/app/outputs/flutter-apk/app-prod-release.apk` (`281M` / `294.0MB`, SHA-256 `0f7ae6044dd25e6c17ed108e2280feb662ae6d6fc1e81ae7eec291097fdb105d`), pendiente únicamente de firma local del usuario con `$HOME/keystores/moneo-release.jks` y validación en dispositivo.
- **Sprint `pulido-visual-web` consolidado en `main`:**
  - **P0 (Accesibilidad, contraste WCAG AA/AAA y tokens):** Tokens centralizados en `lib/themes/app_theme_data.dart` (`borderVisible`, `foregroundOn`, `datePickerThemeWithAccent`, umbral `onSecondary > 0.25`, `_nocturno.secondaryCardBackground: 0xFF252733`), objetivos táctiles `>= 48dp`, `Semantics` unificada y cero literales opacos rotos en diálogos/formularios.
  - **P1 (`Home` + `TotalBalanceWidget`):** Jerarquía balance-first (`Disponible` 32px tabular, `MoneoSegmentedControl` junto al historial, agrupación temporal `"Hoy · ..."`, color-coding de categoría, hora `HH:mm` y estado vacío accionable).
  - **P2 (Estados vacíos accionables y `360x640 @ 1.35x`):** Resueltos overflows en `360x640 @ TextScaler 1.35x` y añadidos CTA `>= 48dp` en `ResponsibilitiesScreen`, `AnnualProjectionScreen`, `CategoriesScreen`, `SelectAccountScreen`, `DailyTransactionsScreen`, `PendingTransactionCard`, `FloatingActionMenuScreen` y `PinCodeScreen`.
  - **Selectores minimalistas de Color e Ícono en ventana emergente:** `.specify/selectores-color-icono/`, `lib/widgets/moneo_color_picker.dart` (rueda polar de 48 colores + 8 rápidos), `lib/utils/app_icons.dart` + `lib/widgets/moneo_icon_picker.dart` (catálogo de 114 ítems en 8 categorías con búsqueda offline conservando los 43 íconos heredados) y `lib/widgets/moneo_appearance_pickers_row.dart` (fila minimalista 48dp lado a lado abriendo diálogos emergentes centrados), integrados en `CategoriesScreen`, `AddAccountDialogs`, `EditAccountDialogs`, `AiChatScreen` y `AddResponsibilityDialog`.
  - **Modo Nocturno y formularios (`add.dart`, `add_expense.dart`, `transfer.dart`, `floating_action_menu_screen.dart`):** Separación nítida de superficies vs `borderVisible`, divisores visibles en `"Nueva Operación"`, botones/chips con contraste AA garantizado (`foregroundOn`) y `DatePicker` temático (`datePickerThemeWithAccent`).
  - **Sin tocar archivos protegidos** ni `lib/Screens/statistics.dart` (reservado para Fase 3 en `wt-f2-archive`).
- **Fase 1 Optimización a Largo Plazo (fusionada en `main`, worktrees y ramas limpiadas):**
  - **IA / Chat:** `AiIntentDetector` + `AiQueryRouter` + funciones deterministas (`ai_financial_tools.dart`: TCO, cuota, interés, depreciación, flujo de caja, transporte) + plantillas (`ai_report_templates.dart`), metas acumulativas, resumen acumulativo, rotación `2048` tokens, historial acotado (80 msgs) y aviso neutro Gemma.
  - **Patrones y Deduplicación:** `LearnedPattern` retrocompatible con estados (`nuevo`, `en_refuerzo`, `consolidado`, `en_revision`, `obsoleto`) y puntuación por categoría/cuenta; `TransactionDedupCorrelator` (`UTR`, `48h` + `>=0.90` con `BM25 + JaccardTrigram`, transferencia interna, `mergePendingItems`/`splitMergedItem`), circuit-breaker Gemma y poda TTL + `compact()` en background.
  - **Agregados O(1):** `MonthlySummaryCache` conectado a `Home`, `Statistics` y `AiChatService`; eliminado `O(N²)` en `TransactionListWidget`.
  - **Validación:** `dart analyze` = `No issues found!`, `flutter test --no-pub -j 1` = **277/277 pasaron** en `main`, y flujos Maestro aprobados en `R5CY21GE9YY` vía `.maestro/docker/run_maestro.sh` (Gemma 2.4 GB descargado y verificado).
- **Suite Maestro Docker y Hooks (`agent/maestro/configuracion-agentica`, fusionada en `main`):**
  - `.agents/hooks/pre_stop_test.sh` y `.agents/hooks/security_guard.py`: resolución dinámica de socket Docker (`DOCKER_HOST`) y reglas de exclusividad/seguridad.
  - `.agents/skills/moneo-maestro-e2e/SKILL.md`, `.maestro/audit_*.yaml`, `.maestro/docker/*` y `.maestro/tests/test_maestro_security_suite.py` (`12/13` pasaron; `test_13` requiere construir la imagen `finazaap-maestro:local`).
  - Quedan únicamente `agent/maestro/configuracion-agentica` (en worktree `wt-maestro-agentic` con 9 archivos `.maestro/verify_*.yaml` sin trackear) y `validation/isolated-debug-apk` / `validation/isolated-profile-apk`.
- **Consolidación de ramas pendientes (`integration/pendientes-web-y-perf`, fusionada en `main`):**
  - Permisos Android (`agent/fix/android-permissions-ux`): separación de `POST_NOTIFICATIONS` vs alarmas exactas, re-verificación al reanudar y guía de ajustes restringidos.
  - Rendimiento, TC, Disponible y Gemma (`agent/perf/profile-bottlenecks`): eliminación de `saveLayer` de `StretchingOverscrollIndicator`, recorte de splash, sincronización de PIN en Ajustes, bloqueo de *"Incluir en saldo total"* en tarjetas de crédito, refresco de `Disponible` tras `Gestionar cuentas` y bloqueo de inferencia Gemma durante descarga.
  - Modelo Gemma editable (`agent/ai/default-model-url-ui`): pre-carga de URL de modelo por defecto editable con opción de restaurar.
  - Validación: `dart analyze` (`No issues found!`) en las pruebas nuevas/actualizadas, `flutter test --no-pub -j 1` (**244/244 pasaron**) y `flutter build web --no-pub --no-tree-shake-icons` (`✓ Built build/web`). Limpiadas 22 ramas ya integradas y 4 worktrees; quedan únicamente `agent/maestro/configuracion-agentica` (`wt-maestro-agentic`), `agent/maestro/audit-e2e` y `validation/isolated-*`.
- **Onboarding e Incremental UI (`integration/onboarding-y-mejoras-ui`, fusionada en `main`):**
  - Spec y diseño en `.specify/onboarding-y-mejoras-ui/` + `.agents/skills/moneo-ui-design/SKILL.md` (100% offline).
  - Lote 1 (mejoras UI incrementales): `AnnualProjectionScreen` (FAB `Semantics`/`tooltip`, bottom clearance), `Statistics` (fecha sin truncamiento), `PendingTransactionsScreen` (padding inferior), `CategoriesScreen` (estado vacío accionable sin auto-siembra), y validación consistente en formularios (`add_expense.dart`, `transfer.dart`, `add_account_dialogs.dart`).
  - Lote 2 (onboarding): `OnboardingService` (`onboarding_completed`, `onboarding_skipped`, `onboarding_last_step`, detección de usuario existente sin mutar datos), `OnboardingScreen` de 5 pasos (sin `'Tarjeta de crédito'` en Paso 3, diálogo `_CreateCategoryDialog` sin `LayoutBuilder` en `AlertDialog`, `excludeSemantics: true` en indicador de paso), `AuthSplashScreen` y entrada `"Guía inicial"` en `SettingsScreen`.
  - Validación: `236/236` tests en Docker (`finazaap-flutter-env:3.44.2`), flujo E2E Maestro `.maestro/onboarding_y_mejoras_ui_validation.yaml` aprobado en `R5CY21GE9YY` (`com.example.finazaap.validation`). Worktree `wt-onboarding-ui` y ramas `integration/onboarding-y-mejoras-ui` / `agent/ui/onboarding-y-mejoras` eliminados.
- **Entorno Docker reproducible:** `Dockerfile` y `docker-compose.yml` fijados en `FLUTTER_VERSION=3.44.2` (`image: finazaap-flutter-env:3.44.2`).
- **Correcciones integradas en `main` (`agent/maestro/audit-fixes`):**
  - Formularios (`add_expense.dart`, `add.dart`, `transfer.dart`): conservan estado ante validación inválida, muestran `'Sin categorías · Crear'` navegando a `CategoriesScreen` y preservan fecha completa.
  - UI/Accesibilidad (`liquid_glass_surface.dart`, `selecctaccount.dart`, `daily_transactions.dart`, `categories_screen.dart`, `settings_screen.dart`): clearance sobre FAB (`108px`), `Semantics` y `tooltip` en FABs (`Nueva operación`, `Nueva cuenta`, `Nueva categoría`), y selector de divisa separado en `Ajustes`.
  - Divisas y TC (`currency_helper.dart`, `credit_card_calculator.dart`): código ISO (`COP`) en importes ambiguos y documentación de regla post-corte en cuotas de TC.
  - IA offline (`ai_chat_service.dart`): sin descarga automática de Gemma al abrir `Chat`, con métricas de intentos/red/bytes.
  - Flavor de validación (`android/app/build.gradle`): `productFlavors` (`prod` + `validation` con `applicationIdSuffix ".validation"`).
  - Refresco de `Disponible` (`home.dart`) e inicialización Hive de `ResponsibilityService` (`main.dart` + `_ensureBox()` en `responsibility_service.dart`).
- **Pendiente:** medición de rendimiento en `--profile` (`app-validation-profile.apk` pendiente de recompilar/instalar/medir tras aprobación) y `git push` cuando el usuario lo autorice.
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
