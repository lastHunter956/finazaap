# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `agent/ui/t1-3c-daily-transactions-delete` @ `82322c8`  
> **Estado:** **Lote Wave 1 (`L1.1`, `T1.3c`, `T1.4`) + `T3.4` + `T4.1` completado y verificado** (`165/165` tests en Docker). Ver detalle y cola de permisos en `docs/audit/CONTINUITY_STATE.md` (Sección 6).

## Primera Tarea Ejecutable (Siguiente Sesión)
1. [x] Estabilizar `test/audit/t1_3c_ui_deletion_test.dart` y corregir `L1.1` en `lib/Screens/daily_transactions.dart` delegando `_deleteTransaction` a `TransactionService.deleteTransaction(transaction)` (`fcbb7d6`).
2. [x] Completar `T1.3c` (`L1.3`, `L1.8`, `L2.1`, `L2.2`, `L3.1`, `L5.1`), `T1.4`, `T3.4` y `T4.1` (`bd9da6e`, `2de9a61`, `aac8c93`, `c43a3ea`, `82322c8`) con `165/165` tests en verde en Docker (`finazaap-flutter`).
3. [ ] Continuar con `T4.2` / `T4.3` (elegibles sin permisos pendientes) o resolver autorizaciones/decisiones pendientes (`T0.3`, `T3.1`/`T3.2`, `D1`, `currencyCode`).

## Objetivo
Entregar la propuesta visual completa en `integration/ui-temas-y-asistente`: tratamiento Apple HIG / Liquid Glass y física `SpringSimulation` exclusivos de `Diurno` (solo en capa funcional y controles de transición), corrección WCAG AA/AAA en `Día` y `Nocturno` (Dracula), preservación de `Default`, resolución dinámica de solapamientos barra inferior / botón `+` / listas, conversaciones editoriales y `Perfil Cognitivo` coherente en `AiChatScreen`, y encabezados unificados `MoneoHeaderBar` en todas las pantallas del proyecto.

## Plan Activo
1. [x] **Fase 1 — Tokens y Contraste WCAG 2.1 AA/AAA (`lib/themes/app_theme_data.dart`):**
   - Contraste AA (`>=4.5:1`) y AAA (`>=7.0:1`) verificado en las 3 superficies para `Diurno`, `Día` y `Nocturno` (Dracula), manteniendo `_defaultDark` 100% intacto.
2. [x] **Fase 2 y 3 — Liquid Glass Exclusivo de `Diurno` y Retiro de Demo Dev:**
   - `LiquidGlassSurface` en capa funcional con respaldo sólido accesible y eliminación de `"Bandeja de Notificaciones (Demo Dev)"` en `lib/Screens/settings_screen.dart`.
3. [x] **Fase 4 — Trabajo Paralelo Consolidado (5 Frentes Críticos):**
   - **Barra inferior, `+` y Scroll Clearance:** `MoneoLayoutMetrics`, `MoneoNavBarScope`, `MainContainer` (`effectiveBottomClearance`), `CustomPillBottomNavBar` proporcional y dinámica, `FloatingActionMenu` y FABs con contraste AA, y `scrollBottomPadding` en listas.
   - **Movimiento físico real en `Diurno`:** `MoneoSpringMotion` (`SpringSimulation`) y `MoneoPressableScale` en barra inferior, controles segmentados y acciones principales, respetando `disableAnimations` / accesibilidad.
   - **Conversación editorial (`AiChatScreen`):** burbujas limpias sin círculos/headers repetidos ni bordes/sombras multicapa, ancho orgánico sin `Spacer()`, cero `BackdropFilter` en mensajes/reportes, y tarjetas estructuradas solo en sugerencias accionables.
   - **Perfil Cognitivo adaptativo:** eliminación de `.substring(0, 12)` y marcas decorativas, conservando métricas reales de `AiChatService` con layout responsive a ancho y `TextScaler`.
   - **Encabezados unificados (`MoneoHeaderBar` y `MoneoSegmentedControl`):** `primaryTab`, `subScreen` y `form` en las 13 pantallas del proyecto con `TextStyle` 100% offline y `preferredHeightFor` calibrado para escalado de texto y badges.
4. [x] **Pruebas Separadas y Servidor Web Local:**
   - `test/themes/app_theme_contrast_test.dart` (4 tests de tokens/contraste) + `test/widgets/ui_layout_and_navigation_test.dart` (6 tests de layout, FAB/nav clearance, `SpringSimulation`, `AiChatScreen`, `Perfil Cognitivo` y `MoneoHeaderBar`).
   - `dart analyze` limpio en archivos editados y `flutter test --no-pub -j 1` **104/104 pasaron** en Docker (`finazaap-flutter`).
   - Servidor web debug local revisado por el usuario en `http://localhost:8080`.
5. [x] **Validación visual humana y merge a `main`:** Aprobación explícita del usuario sobre `integration/ui-temas-y-asistente` (`af1fbf5`), consolidación en `main` mediante `--ff-only` y re-ejecución de análisis y suite completa en `main`.
6. [ ] **Prueba en teléfono físico (`adb install` pendiente de aprobación explícita):** Compilar APK debug desde `main`, verificar firma/hash/dispositivo/preservación de datos y solicitar autorización explícita antes de instalar en el teléfono.
7. [ ] **Validación real ampliada de notificaciones (sesión futura en `R5CY21GE9YY`):** Gasto real, ingreso real, transferencia entre cuentas propias, duplicados/actualizaciones, confirmación repetida/reinicio, descarte sin mutación contable, app no seleccionada, notificación ambigua, URL no accionable y *force stop* + reapertura.
8. [ ] **Publicación remota (`git push`):** Pendiente de aprobación explícita del usuario.

## Criterio de Término
- `Default` sin cambios en tokens y `Nocturno` (Dracula), `Día` y `Diurno` con AA/AAA en las 3 superficies verificados en `test/themes/app_theme_contrast_test.dart`.
- `LiquidGlassSurface`, no solapamiento barra/`+`, `SpringSimulation` en `Diurno`, `AiChatScreen` (teclado abierto, burbujas orgánicas, cero `BackdropFilter` en mensajes, `Perfil Cognitivo` sin truncamiento) y `MoneoHeaderBar` verificados en `test/widgets/ui_layout_and_navigation_test.dart`.
- `main` verificada tras merge con `dart analyze` y `flutter test --no-pub -j 1`, sin ramas de integración ni worktrees residuales, y APK debug documentada para instalación aprobada en teléfono físico.
