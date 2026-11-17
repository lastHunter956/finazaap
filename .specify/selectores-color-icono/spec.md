# Spec — Selectores Minimalistas Lado a Lado de Color e Ícono (`selectores-color-icono`)

> **Módulo:** `selectores-color-icono` (parte de `integration/pulido-visual-web`)
> **Skills rectoras:** `moneo-ui-design`, `mobile-app-ui-design`, `api-and-interface-design`

## 1. Objetivo
Crear **2 componentes reutilizables** coherentes con la estética minimalista de Moneo (`Default`, `Diurno`, `Día`, `Nocturno`):
1. **`MoneoColorPicker`** (`lib/widgets/moneo_color_picker.dart`): trigger minimalista compacto (`48dp`) + panel desplegable inline con **rueda cromática accesible de 48 tonos** (12 matices × 4 niveles de intensidad/claridad) y barra de favoritos rápidos.
2. **`MoneoIconPicker`** (`lib/widgets/moneo_icon_picker.dart`): trigger minimalista compacto (`48dp`) + panel desplegable inline con **~100+ íconos Material específicos (no genéricos)** organizados en categorías temáticas y con buscador offline en español.

## 2. Reglas Visuales y de UX Obligatorias
- **Estado colapsado minimalista (crítico):** Los dos triggers viven **lado a lado** en una sola fila compacta (`height: 48dp`, estilo idéntico a los dropdowns/inputs de Moneo: fondo `t.darkBackground`, borde `1px` `t.borderSubtle` o `readableColor` si está activo, radio `AppSizes.borderRadiusMedium` = `12dp`). **Prohibido** usar cajas altas/cuadradas comprimidas que rompan el minimalismo.
- **Despliegue inline exclusivo:** Al pulsar `Color` o `Ícono`, se despliega suavemente debajo de la fila (`AnimatedSize`) solo el panel seleccionado (pulsar el otro alterna al otro panel; pulsar el activo colapsa).
- **Color Wheel accesible (`48` colores):** 12 familias cromáticas × 4 anillos de tono/luminancia (`>= 2.6×` los 18 colores previos), operable por toque en segmentos grandes en la rueda `CustomPainter` + modo `Paleta` + 8 favoritos rápidos. Previsualización usando `AppColors.getReadableColor`.
- **Íconos específicos (`>= 95` íconos):** Conserva los **43 `codePoint` históricos** en `AppIcons.allIcons` para retrocompatibilidad 100% con Hive/SharedPreferences y tree-shaking en APK/Web, añadiendo ~65+ íconos específicos agrupados en `Finanzas`, `Comida`, `Transporte`, `Hogar`, `Compras`, `Salud`, `Ocio`, `Trabajo`.
- **Responsividad y Accesibilidad:** Cero overflow en `360×640` con `TextScaler.linear(1.35)` en los 4 temas; `Semantics` (`button`, `expanded`, `selected`, `label`) y `Tooltip` en triggers, rueda e íconos.

## 3. Alcance en Pantallas de la UI
Reemplazar todos los selectores actuales de color e ícono en la aplicación:
1. `lib/Screens/categories_screen.dart` (Crear / Editar Categoría — Color + Ícono lado a lado)
2. `lib/widgets/add_account_dialogs.dart` (Nueva Cuenta — Color + Ícono lado a lado)
3. `lib/widgets/edit_account_dialogs.dart` (Editar Cuenta — Color + Ícono lado a lado)
4. `lib/Screens/ai_chat_screen.dart` (`_showEditSuggestedCategoryDialog` — Color + Ícono lado a lado)
5. `lib/widgets/add_responsibility_dialog.dart` (Nueva / Editar Obligación — Ícono con el nuevo `MoneoIconPicker` minimalista)
