# Plan — Selectores Minimalistas Lado a Lado (`selectores-color-icono`)

## División en 2 Agentes Paralelos (Cero Conflictos) + Integrador

1. **Agente 1 (`agent/ui/selector-color-rueda` en `wt-sel-color`):**
   - Crea `lib/widgets/moneo_color_picker.dart`:
     - `MoneoColorPickerTrigger`: botón compacto `48dp` (`selectedColor`, `isExpanded`, `onTap`, `label: 'Color'`).
     - `MoneoColorPickerPanel`: panel inline con toggle `Rueda` / `Paleta`, rueda cromática de **48 colores** (`CustomPainter` polar de 12 sectores × 4 anillos + selección táctil), 8 favoritos rápidos y preview legible.
     - Lista pública `kMoneoWheelColors` (`48` colores `Color`).
   - Crea `test/widgets/moneo_color_picker_test.dart`.

2. **Agente 2 (`agent/ui/selector-iconos-tematicos` en `wt-sel-icons`):**
   - Actualiza `lib/utils/app_icons.dart`:
     - Conserva intactos los 43 íconos previos en `AppIcons.allIcons`.
     - Agrega `MoneoIconEntry` (`icon`, `label`, `category`, `keywords`) y `AppIcons.catalog` (~105+ íconos Material específicos verificados en Flutter 3.44.2, en 8 categorías temáticas) manteniendo `AppIcons.getIcon(int codePoint)` 100% compatible.
   - Crea `lib/widgets/moneo_icon_picker.dart`:
     - `MoneoIconPickerTrigger`: botón compacto `48dp` (`selectedIcon`, `accentColor`, `isExpanded`, `onTap`, `label: 'Ícono'`).
     - `MoneoIconPickerPanel`: panel inline con campo de búsqueda en español, chips por categoría temática y grilla de íconos.
   - Crea `test/widgets/moneo_icon_picker_test.dart`.

3. **Agente Integrador (`integration/pulido-visual-web` en `wt-pulido-visual`):**
   - Fusiona `agent/ui/selector-color-rueda` y `agent/ui/selector-iconos-tematicos`.
   - Crea `lib/widgets/moneo_appearance_pickers_row.dart` (fila minimalista lado a lado + acordeón inline exclusivo).
   - Integra en `categories_screen.dart`, `add_account_dialogs.dart`, `edit_account_dialogs.dart`, `ai_chat_screen.dart` y `add_responsibility_dialog.dart`.
   - Agrega tests de integración en `360×640 @ 1.35x`, ejecuta `dart analyze`, `flutter test --no-pub -j 1`, `flutter build web`, actualiza `http://localhost:8085` y limpia las 2 ramas/worktrees de agentes.
