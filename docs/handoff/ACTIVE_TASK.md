# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama de integración activa:** `integration/ui-temas-y-asistente` (sin merge a `main`; `main` permanece en `165c1c1`)  
> **Rama de agente:** `agent/ui/fase-1-tokens-contraste` (fusionada vía `--ff-only` en `integration/ui-temas-y-asistente`)  
> **Estado:** **Fases 1, 2 y 3 completadas y consolidadas** — en espera de **validación visual completa del usuario** en el navegador (puerto local `8080`); prohibido instalar en el teléfono o fusionar a `main` sin aprobación explícita.

## Objetivo
Entregar la propuesta visual completa de temas y asistente en `integration/ui-temas-y-asistente`: tratamiento Apple HIG / Liquid Glass exclusivo en `Diurno` (solo capa funcional), corrección de paleta/contraste WCAG AA/AAA en `Día` y `Nocturno` (Dracula), preservación total de `Default`, rediseño integral de `AiChatScreen` en los 4 temas y eliminación de `"Bandeja de Notificaciones (Demo Dev)"`.

## Plan Activo
1. [x] **Fase 1 — Tokens y Contraste WCAG 2.1 AA/AAA (`lib/themes/app_theme_data.dart`):**
   - Garantizado contraste AA (`>=4.5:1`) y AAA (`>=7.0:1`) en texto primario, secundario, hints, acentos y estados frente a las 3 superficies (`primaryBackground`, `cardBackground`, `darkBackground`) en `Diurno`, `Día` y `Nocturno` (Dracula `#282A36` / `#21222C` / `#191A21` / `#44475A`, `#BD93F9`, `#FF79C6`, `#50FA7B`, `#8BE9FD`, `#FFB86C`, `#FF5555`).
   - `_defaultDark` preservado 100% intacto.
2. [x] **Fase 2 — Rediseño Completo de `AiChatScreen` en los 4 Temas (`lib/Screens/ai_chat_screen.dart`):**
   - Corregido el bug de `Spacer()` (burbujas con ancho orgánico en texto plano y `MarkdownBody(fitContent: true)` para Markdown), cabecera única unificada con selector `Simulador`/`Gemma IA` y pestañas, eliminación de colores/bordes neón hardcodeados, sugerencias y diálogos tematizados con `CurrencyHelper`, y composer flotante multilínea.
   - Eliminada `"Bandeja de Notificaciones (Demo Dev)"` de `lib/Screens/settings_screen.dart`.
3. [x] **Fase 3 — Apple HIG & Liquid Glass Exclusivo en `Diurno`:**
   - Implementado `LiquidGlassSurface` con blur (`sigma 22`), gradiente frío translúcido, borde especular (`GradientBoxBorder`), cresta superior e invariante de respaldo escarchado opaco ante preferencias de accesibilidad.
   - Aplicado exclusivamente en capa funcional en `Diurno` (`CustomPillBottomNavBar`, cabecera unificada y composer flotante de `AiChatScreen`; contenido en tarjetas sólidas en `Home` y `TotalBalanceCard`).
4. [x] **Pruebas y Despliegue Web Local:** `dart analyze` limpio en temas/tests, 0 errores en archivos editados, `flutter test -j 1` **102/102 pasaron** en Docker y servidor web debug actualizado en `http://localhost:8080`.
5. [ ] **Validación visual humana del conjunto completo:** Revisión por el usuario en navegador (sin merge a `main` ni instalación móvil sin aprobación).
6. [ ] **Validación real ampliada de notificaciones (sesión futura en `R5CY21GE9YY`):** Gasto real, ingreso real, transferencia entre cuentas propias, duplicados/actualizaciones, confirmación repetida/reinicio, descarte sin mutación contable, app no seleccionada, notificación ambigua, URL no accionable y *force stop* + reapertura.
7. [ ] **Publicación remota (`git push`) y merge a `main`:** Pendientes de validación humana completa y aprobación explícita.

## Criterio de Término
- `Default` sin cambios en tokens y `Nocturno` (Dracula), `Día` y `Diurno` con AA/AAA en las 3 superficies verificados por test.
- `LiquidGlassSurface` exclusivo en `Diurno` y con respaldo sólido accesible verificado por test widget.
- `AiChatScreen` sin overflows en `360x640`, con teclado abierto, textos largos y ancho orgánico verificado en los 4 temas.
- Rama `integration/ui-temas-y-asistente` conservada sin merge a `main` hasta validación visual del usuario.
