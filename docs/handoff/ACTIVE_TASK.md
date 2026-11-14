# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama de integración activa:** `integration/ui-temas-y-asistente` (sin merge a `main`; `main` permanece en `165c1c1`)  
> **Rama de agente:** `agent/ui/fase-1-tokens-contraste`  
> **Estado:** **Fase 1 (Tokens y Contraste) completada** — en espera de **validación visual del usuario** antes de iniciar la Fase 2 (Asistente Financiero `AiChatScreen`) y la Fase 3 (Liquid Glass moderado solo en `Diurno`).

## Objetivo
Mejorar contraste, legibilidad y coherencia visual en `Diurno`, `Día` y `Nocturno` (paleta oficial Dracula), manteniendo `Default` intacto, rediseñando posteriormente el Asistente Financiero (`AiChatScreen`) y aplicando Liquid Glass moderado solo en barra inferior y composer en `Diurno`.

## Plan Activo
1. [x] **Fase 1 — Tokens y Contraste (`integration/ui-temas-y-asistente`):**
   - Artefactos `.specify/ui-temas-y-asistente/{spec.md,plan.md,tasks.md}`.
   - Nuevos tokens WCAG 2.1 AA/AAA para `_diurno` y `_dia`; paleta oficial Dracula para `_nocturno`; `_defaultDark` intacto en `lib/themes/app_theme_data.dart`.
   - Corrección de colores hardcodeados en `lib/widgets/total_balance_widget.dart`, `lib/widgets/custom_pill_bottom_nav_bar.dart`, `lib/Screens/settings_screen.dart` y `lib/Screens/statistics.dart`.
   - Suite `test/themes/app_theme_contrast_test.dart` + validación completa en Docker (`flutter test -j 1`: 99/99).
2. [ ] **Validación visual humana de Fase 1:** Revisar `Diurno`, `Día`, `Default` y `Nocturno` en la app y autorizar paso a Fase 2.
3. [ ] **Fase 2 — Rediseño de `AiChatScreen`:** Corregir bug de `Spacer()` en burbujas, unificar las 3 barras superiores en cabecera única, eliminar bordes neón y colores hardcodeados, implementar composer flotante (Dracula en `Nocturno`, sin glass aún) y tarjetas de sugerencias con `CurrencyHelper`.
4. [ ] **Fase 3 — Liquid Glass en `Diurno`:** Aplicar `BackdropFilter` / `ImageFiltered` moderado únicamente a `CustomPillBottomNavBar` y composer de `AiChatScreen` en `Diurno` con variante sólida de respaldo, y validar rendimiento/legibilidad en `Samsung SM_S721B`.
5. [ ] **Validación real ampliada de notificaciones (sesión futura en `R5CY21GE9YY`):** Gasto real, ingreso real, transferencia entre cuentas propias, duplicados/actualizaciones, confirmación repetida/reinicio, descarte sin mutación contable, app no seleccionada, notificación ambigua, URL no accionable y *force stop* + reapertura.
6. [ ] **Publicación remota (`git push`) y merge a `main`:** Pendientes de validación humana completa y aprobación explícita.

## Criterio de Término de Fase 1
- `Default` sin modificaciones y `Nocturno` con paleta oficial Dracula verificados por test.
- Contrastes WCAG 2.1 AA/AAA verificados en `test/themes/app_theme_contrast_test.dart` y `flutter test -j 1` (100% pass en Docker).
- Rama `integration/ui-temas-y-asistente` conservada sin merge a `main` hasta validación visual del usuario.
