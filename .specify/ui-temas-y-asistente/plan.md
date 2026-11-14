# Plan Técnico — Fase 1: Tokens y Contraste

> **Módulo:** `ui-temas-y-asistente`
> **Alcance de este plan:** Fase 1 (Tokens, Contraste WCAG 2.1 y eliminación de colores hardcodeados críticos sin cambiar estructura ni añadir blur/glass).

---

## 1. Arquitectura de Tokens en `lib/themes/app_theme_data.dart`

1. **`_defaultDark`:** Sin cambios (verificado bit a bit).
2. **`_diurno` (Cool Alabaster / Apple Light solid base):**
   - `primaryBackground`: `0xFFEEF2F8` (separa claramente tarjetas blancas del lienzo).
   - `cardBackground`: `0xFFFFFFFF`.
   - `secondaryCardBackground`: `0xFFF7F9FC`.
   - `darkBackground`: `0xFFE2E8F2` (wells/inputs).
   - `textPrimary`: `0xFF0B132B` (AAA), `textSecondary`: `0xFF334155` (AAA), `textHint`: `0xFF52637A` (AA).
   - `accent`: `0xFF0062CC`, `secondaryAccent`: `0xFF4F46E5`, `income`/`success`: `0xFF047857`, `warning`: `0xFFB45309`, `expense`/`error`: `0xFFBE123C`.
   - `buttonBackground`: `0xFF0062CC`, `buttonForeground`: `Colors.white`, `filledButtons: true`.
3. **`_dia` (Warm Pearl / Stone Quartz, sin amarillo saturado ni morado/violeta):**
   - `primaryBackground`: `0xFFF4EFE6`, `cardBackground`: `0xFFFFFDF9`, `secondaryCardBackground`: `0xFFFAF6F0`, `darkBackground`: `0xFFE6DFD3`.
   - `textPrimary`: `0xFF1C1917` (AAA), `textSecondary`: `0xFF44403C` (AAA), `textHint`: `0xFF68625D` (AA).
   - `accent`: `0xFF0F766E`, `secondaryAccent`: `0xFFB45309`, `income`/`success`: `0xFF15803D`, `warning`: `0xFFB45309`, `expense`/`error`: `0xFFB91C1C`.
   - `buttonBackground`: `0xFF0F766E`, `buttonForeground`: `Colors.white`, `filledButtons: true`.
4. **`_nocturno` (Paleta Oficial Dracula):**
   - `primaryBackground`: `0xFF282A36`, `cardBackground`: `0xFF313442`, `secondaryCardBackground`: `0xFF44475A`, `darkBackground`: `0xFF1E1F29`.
   - `textPrimary`: `0xFFF8F8F2`, `textSecondary`: `0xFFB4BCCF`, `textHint`: `0xFF6272A4`.
   - `borderSubtle`: `0xFF44475A`, `borderVisible`: `0xFF6272A4`.
   - `accent`: `0xFFBD93F9`, `secondaryAccent`: `0xFF8BE9FD`, `income`/`success`: `0xFF50FA7B`, `warning`: `0xFFFFB86C`, `expense`/`error`: `0xFFFF5555`.
   - Constante adicional en `AppTheme`: `static const Color draculaPink = Color(0xFFFF79C6);`.
   - `buttonBackground`: `0xFFBD93F9`, `buttonForeground`: `0xFF282A36`, `filledButtons: true`.
5. **`buildThemeData()`:**
   - Calcular `onSecondary` adaptativo según luminancia de `secondaryAccent` para que en `Nocturno` (`#8BE9FD`) tenga texto oscuro `#282A36` y contraste AAA.

---

## 2. Ajustes de Colores Hardcodeados en Widgets (Fase 1)

1. `lib/widgets/total_balance_widget.dart`:
   - Reemplazar `#50FA7B` y `#FF7D7D` hardcodeados del anillo por `context.appTheme.income` y `context.appTheme.expense`.
   - Evitar verde `#50FA7B` (y texto de acento de baja legibilidad en texto pequeño) en la etiqueta de `9.5px` (`EXCEDIDO`/`COMPLETO`/`RESTANTE`) en temas oscuros usando `context.appTheme.textPrimary`, y retirar sombras negras en modo claro.
   - Agregar borde sutil y `elevation: 0` en los botones `Gestionar cuentas`, selector de fecha y filtros `Todos`/`Gastos`/`Ingresos` para que sean distinguibles en `Diurno` y `Día`.
   - Eliminar `Colors.white` fijo en `_buildSectionLabel`.
2. `lib/Screens/settings_screen.dart`:
   - Reemplazar `Colors.white` y `Colors.white70` en los diálogos `_importData` y `_confirmDeleteAllData` por `context.appTheme.textPrimary` y `context.appTheme.textSecondary`.
3. `lib/Screens/statistics.dart`:
   - Reemplazar `Colors.white70`, `Colors.white54`, `Colors.white10`, `Colors.white` y `Colors.white24` en `_buildBarChart` por tokens de `context.appTheme`.
4. `lib/widgets/custom_pill_bottom_nav_bar.dart`:
   - Agregar borde `borderSubtle` y suavizar la sombra en modo claro (`alpha: 0.08`) sin añadir blur ni glass (diferido a Fase 3).

---

## 3. Verificación

- `test/themes/app_theme_contrast_test.dart` validará las constantes exactas de `Default` y `Nocturno` Dracula, y verificará ratios WCAG 2.1 en los 4 temas.
- `docker-compose exec -T flutter-env dart analyze` y `docker-compose exec -T flutter-env flutter test -j 1`.
