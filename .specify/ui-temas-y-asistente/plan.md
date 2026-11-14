# Plan Técnico Completo — Temas (`Diurno Liquid Glass`, `Día`, `Nocturno Dracula`) y Asistente Financiero

> **Módulo:** `ui-temas-y-asistente`
> **Alcance:** Tokens AA/AAA estrictos, material Liquid Glass exclusivo para `Diurno` fundamentado en Apple HIG, retiro de `"Bandeja de Notificaciones (Demo Dev)"`, y rediseño integral de `AiChatScreen` en los 4 temas.

---

## 1. Arquitectura de Tokens y Material Liquid Glass (`lib/themes/app_theme_data.dart`)

1. **Ajustes estrictos de contraste (`>= 4.5:1` en las 3 superficies base):**
   - `_diurno`: `income: Color(0xFF046B4D)`, `success: Color(0xFF046B4D)`, `warning: Color(0xFF92400E)`.
   - `_dia`: `accent: Color(0xFF0E665F)`, `buttonBackground: Color(0xFF0E665F)`, `secondaryAccent: Color(0xFF92400E)`, `warning: Color(0xFF92400E)`, `income: Color(0xFF146C34)`, `success: Color(0xFF146C34)`.
   - `_nocturno`: `cardBackground: Color(0xFF21222C)` (Dracula ANSI Black), `darkBackground: Color(0xFF191A21)`, `textSecondary: Color(0xFFC6CEE0)`, `textHint: Color(0xFF909EC7)`, manteniendo `draculaComment = Color(0xFF6272A4)` para bordes/separadores y `draculaPink = Color(0xFFFF79C6)`.
   - `_defaultDark`: 100% sin cambios.
2. **`AppThemeExt` + `LiquidGlassSurface` (en `lib/themes/app_theme_data.dart`, respetando `no-new-files-by-default`):**
   - `bool get isDiurno` detecta `ThemeNotifier.activeMode == AppThemeMode.diurno` (y si un test inyecta `ThemeData` con extensión `_diurno`, también compara por identidad/paleta de extensión cuando corresponda).
   - `LiquidGlassSurface` encapsula el renderizado condicional:
     - En `Día`, `Nocturno`, `Default`: superficie sólida con `borderSubtle`, sin `BackdropFilter`.
     - En `Diurno` con accesibilidad activa (`accessibleNavigation`, `highContrast`, `disableAnimations`): respaldo escarchado opaco `Color(0xF5FFFFFF)` con borde `#8496B0`, sin `BackdropFilter`.
     - En `Diurno` estándar: `ClipRRect` + `BackdropFilter(sigma: blurSigma)` + tinte traslúcido frío + bisel especular `GradientBoxBorder` + reflejo cenital superior de `1px` + sombra ambiental bicapa.

---

## 2. Superficies y Controles Apple en `Diurno`

1. `lib/Screens/main_container.dart`: `extendBody: context.isDiurno` para permitir el paso real de contenido debajo de `CustomPillBottomNavBar`.
2. `lib/widgets/custom_pill_bottom_nav_bar.dart`: en `Diurno`, envuelve la cápsula en `LiquidGlassSurface` y renderiza el ítem seleccionado como lente activa de cristal especular; en los demás temas conserva su apariencia sólida.
3. `lib/Screens/home.dart`:
   - En `Diurno`, `AppBar` perlado con divisor inferior especular y botón de Asistente Financiero en cápsula con bisel blanco/azul; elimina colores hardcodeados (`Colors.green`, `Colors.redAccent`, `Colors.lightBlueAccent`, `Colors.greenAccent`) que rompían el contraste en temas claros en `_buildDateSection` y `_buildTransactionItem`.
4. `lib/widgets/total_balance_widget.dart`:
   - En `Diurno`, tarjeta sólida con gradiente cenital sutil y borde especular (sin blur, por ser capa de contenido), botones en cápsula elevada y filtros `Todos`/`Gastos`/`Ingresos` dentro de un **Segmented Pill Track** estilo Apple (`#E2E8F2` + píldora activa blanca elevada); en los demás temas conserva el layout estándar.
   - Corregir color hardcodeado `Colors.redAccent` en balance contable negativo usando `context.appTheme.expense`.

---

## 3. Retiro de Demo Dev en Ajustes (`lib/Screens/settings_screen.dart`)

- Remover `settings_notifications_demo_tile` (`"Bandeja de Notificaciones (Demo Dev)"`) y sus imports huérfanos (`foundation`, `simulated_notification_source`).
- Dar acabado táctil Apple al selector de temas en `Diurno`.

---

## 4. Rediseño Integral del Asistente Financiero (`lib/Screens/ai_chat_screen.dart`)

1. Migrar al 100% de `AppColors.*` / hexadecimales hardcodeados a `context.appTheme`.
2. Unificar cabecera (`Asistente Financiero` + selector `Simulador`/`Gemma IA` + tabs `Consultas`/`Perfil Cognitivo`) flotando con `LiquidGlassSurface` en `Diurno` y sólido en el resto.
3. Corregir bug del `Spacer()` en `_buildChatBubble`, aplicando ancho orgánico (`IntrinsicWidth` + `ConstrainedBox`), bordes limpios sin neón (`t.borderSubtle`) y burbuja de usuario tematizada con contraste AA/AAA.
4. Composer flotante (`LiquidGlassSurface` en `Diurno`, sólido en el resto) con `TextField` expansible de 1 a 4 líneas, `SafeArea` y ajuste seguro ante teclado abierto (`viewInsets`) en pantallas móviles (`360x640`).
5. Unificar moneda con `CurrencyHelper.format(...)` en tablero inicial, métricas y barras de categoría, y tematizar tarjetas de sugerencias y diálogos de edición.

---

## 5. Verificación

- `test/themes/app_theme_contrast_test.dart`: contrastes exactos AA (`>= 4.5:1`) y AAA (`>= 7.0:1`) en las 3 superficies para `Diurno`, `Día` y `Nocturno` (Dracula), preservando `Default` intacto.
- `test/widgets/ui_layout_and_navigation_test.dart`: exclusividad de `BackdropFilter` en `LiquidGlassSurface` y banderas de accesibilidad, no solapamiento `CustomPillBottomNavBar` vs `FloatingActionMenu` (`+`) con continuidad `SpringSimulation` en `360x640` + `TextScaler 1.35`, `AiChatScreen` (ancho orgánico de burbujas, teclado abierto, cero `BackdropFilter` en burbujas y `Perfil Cognitivo` sin truncamiento `.substring`), y responsividad de las 3 variantes de `MoneoHeaderBar` + `MoneoSegmentedControl`.
- Ejecución completa en Docker (`dart analyze` + `flutter test --no-pub -j 1`, **104/104** pruebas pasando) y despliegue en servidor web debug (`8080`) sobre `integration/ui-temas-y-asistente`.

---

## 6. Arquitectura Consolidada en Fase 4 (Multi-Worktree -> `integration/ui-temas-y-asistente`)

- **Contratos compartidos (`lib/widgets/liquid_glass_surface.dart` y `lib/widgets/moneo_header_bar.dart`):**
  - Extracción de `LiquidGlassSurface` fuera de `lib/themes/app_theme_data.dart` (re-exportado por compatibilidad), incorporación de `MoneoLayoutMetrics`, `MoneoNavBarScope`, `MoneoSpringMotion` (`SpringSimulation` real), `MoneoPressableScale`, `MoneoHeaderBar` (`primaryTab`, `subScreen`, `form`) y `MoneoSegmentedControl`.
  - Uso de `TextStyle` nativo (sin descargas HTTP de `google_fonts`) en `MoneoHeaderBar` y ajuste de `preferredHeightFor` para escalados de texto y badges sin overflows.
- **Ramas consolidadas y retiradas tras pruebas en worktrees aislados:**
  - `agent/ui/nav-and-fab-layout` (`MainContainer`, `CustomPillBottomNavBar`, `FloatingActionMenu`, `TotalBalanceCard`).
  - `agent/ui/chat-and-cognitive-profile` (`AiChatScreen`: conversación editorial y `Perfil Cognitivo` adaptativo).
  - `agent/ui/screens-headers-and-scroll-padding` (13 pantallas principales, detalle y formularios con `MoneoHeaderBar` y `MoneoLayoutMetrics.scrollBottomPadding`).
