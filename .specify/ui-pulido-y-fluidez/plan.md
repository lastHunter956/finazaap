# Plan Técnico — `ui-pulido-y-fluidez`

## Arquitectura de Ejecución Paralela (4 Subagentes sin Solapamiento)

Se crea la rama de integración `integration/ui-pulido-y-fluidez` a partir de `integration/notificaciones-rag-y-multi-ia` (`21ece12`) para mantener integradas todas las mejoras de notificaciones + Multi-IA + Spam junto con el pulido UI/fluidez.

Cada subagente trabaja en un worktree `share` aislado y en una rama `agent/ui/<tarea>` propia sobre un conjunto de archivos **estrictamente disjunto**:

1. **`agent/ui/motion-y-navegacion` (Sistema de Movimiento, Tema Base y Navegación):**
   - `lib/themes/app_theme_data.dart`
   - `lib/main.dart`
   - `lib/widgets/liquid_glass_surface.dart`
   - `lib/Screens/main_container.dart`
   - `lib/widgets/custom_pill_bottom_nav_bar.dart`
   - `lib/widgets/floating_action_menu.dart`
   - `lib/widgets/floating_action_menu_screen.dart`

2. **`agent/ui/home-y-balance-fintech` (Rediseño Hero Balance, `Home` y Listas):**
   - `lib/widgets/total_balance_widget.dart`
   - `lib/Screens/home.dart`
   - `lib/widgets/transaction_list_widget.dart`

3. **`agent/ui/modales-fluidez-y-pantallas` (Cero Blur Jank en Modales + Categorías/Pagos/Cuentas):**
   - `lib/Screens/categories_screen.dart`
   - `lib/Screens/responsibilities_screen.dart`
   - `lib/Screens/selecctaccount.dart`
   - `lib/Screens/annual_projection_screen.dart`
   - `lib/widgets/account_dialogs.dart`
   - `lib/widgets/add_account_dialogs.dart`
   - `lib/widgets/edit_account_dialogs.dart`
   - `lib/widgets/add_responsibility_dialog.dart`
   - `lib/widgets/responsibility_actions_menu.dart`
   - `lib/features/notifications/presentation/widgets/correction_dialog.dart`

4. **`agent/ui/chat-ajustes-y-tipografia` (Eliminación 96 `GoogleFonts` + Pulido Chat/Ajustes/Header):**
   - `lib/Screens/ai_chat_screen.dart`
   - `lib/Screens/settings_screen.dart`
   - `lib/widgets/moneo_header_bar.dart`

## Fase de Integración y Verificación (Orquestador)
1. Merge ordenado de las 4 ramas `agent/ui/*` en `integration/ui-pulido-y-fluidez`.
2. Validación en Docker (`finazaap-flutter`):
   - `dart analyze` limpio en todos los archivos tocados.
   - `flutter test --no-pub -j 1` sobre la suite completa (temas, UI/layout, notificaciones, IA, onboarding, widgets) + nuevas pruebas de regresión de fluidez/bottom sheets/cero `BackdropFilter` en modales.
3. Actualización de `docs/handoff/CURRENT_STATE.md` y `docs/handoff/ACTIVE_TASK.md`.
4. Compilación de APK `prod` release en Docker (si procede/solicitado) y entrega para validación humana en dispositivo antes de tocar `main`.
