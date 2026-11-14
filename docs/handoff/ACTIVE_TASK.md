# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama de integración activa:** `integration/ui-temas-y-asistente` (sin merge a `main`; `main` permanece en `165c1c1`)  
> **Ramas consolidadas y retiradas:** `agent/ui/fase-1-tokens-contraste`, `agent/ui/nav-and-fab-layout`, `agent/ui/chat-and-cognitive-profile`, `agent/ui/screens-headers-and-scroll-padding`  
> **Estado:** **Fases 1–4 completadas y consolidadas** — en espera de **validación visual completa del usuario** en el navegador (puerto local `8080`); prohibido instalar en el teléfono o fusionar a `main` sin aprobación explícita.

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
   - Servidor web debug reiniciado en `http://localhost:8080`.
5. [ ] **Validación visual humana del conjunto completo:** Revisión por el usuario en navegador (sin merge a `main` ni instalación móvil sin aprobación).
6. [ ] **Validación real ampliada de notificaciones (sesión futura en `R5CY21GE9YY`):** Gasto real, ingreso real, transferencia entre cuentas propias, duplicados/actualizaciones, confirmación repetida/reinicio, descarte sin mutación contable, app no seleccionada, notificación ambigua, URL no accionable y *force stop* + reapertura.
7. [ ] **Publicación remota (`git push`) y merge a `main`:** Pendientes de validación humana completa y aprobación explícita.

## Criterio de Término
- `Default` sin cambios en tokens y `Nocturno` (Dracula), `Día` y `Diurno` con AA/AAA en las 3 superficies verificados en `test/themes/app_theme_contrast_test.dart`.
- `LiquidGlassSurface`, no solapamiento barra/`+`, `SpringSimulation` en `Diurno`, `AiChatScreen` (teclado abierto, burbujas orgánicas, cero `BackdropFilter` en mensajes, `Perfil Cognitivo` sin truncamiento) y `MoneoHeaderBar` verificados en `test/widgets/ui_layout_and_navigation_test.dart`.
- Rama `integration/ui-temas-y-asistente` conservada sin merge a `main` hasta validación visual del usuario.
