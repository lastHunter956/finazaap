# Tareas — `ui-pulido-y-fluidez`

- [x] **T0 — Spec Kit y rama de integración `integration/ui-pulido-y-fluidez`:**
  - [x] Crear rama `integration/ui-pulido-y-fluidez` desde `integration/notificaciones-rag-y-multi-ia` (`21ece12`).
  - [x] Escribir `spec.md`, `plan.md` y `tasks.md`.

- [x] **T1 — Subagente 1 (`agent/ui/motion-y-navegacion` @ `e95455e`):**
  - [x] Añadir `textTheme`, `pageTransitionsTheme`, `bottomSheetTheme`, `dialogTheme` y `snackBarTheme` en `lib/themes/app_theme_data.dart` preservando intactos los tokens de color de los 4 temas.
  - [x] Extender `MoneoSpringMotion` y `MoneoPressableScale` a los 4 temas (manteniendo `LiquidGlassSurface` con `BackdropFilter` exclusivo de `Diurno`).
  - [x] Unificar scroll limpio en `lib/main.dart`, añadir cross-fade suave + haptics + `RepaintBoundary` en `MainContainer` y `CustomPillBottomNavBar`, y eliminar `BackdropFilter` + anclar en zona del pulgar en `FloatingActionMenuScreen`.

- [x] **T2 — Subagente 2 (`agent/ui/home-y-balance-fintech` @ `c4f0609`):**
  - [x] Rediseñar `TotalBalanceWidget` (anillo custom redondeado y animado `BudgetArcPainter`, menos cajas anidadas, selector mes/año en Bottom Sheet sin `BackdropFilter`).
  - [x] Optimizar `Home` (eliminar doble rebuild, `AnimatedSize` + `AnimatedRotation` en secciones de fecha, tarjeta contraída compacta y filas de transacción limpias).
  - [x] Modernizar `TransactionListWidget` eliminando colores/sombras hardcodeados heredados.

- [x] **T3 — Subagente 3 (`agent/ui/modales-fluidez-y-pantallas` @ `41331b2`):**
  - [x] Eliminar los `BackdropFilter` pesados en `categories_screen.dart`, `responsibilities_screen.dart`, `selecctaccount.dart`, `annual_projection_screen.dart`, `account_dialogs.dart`, `add_account_dialogs.dart`, `edit_account_dialogs.dart`, `add_responsibility_dialog.dart`, `responsibility_actions_menu.dart` y `correction_dialog.dart`.
  - [x] Corregir parpadeo de spinner en `CategoriesScreen` al cambiar de pestaña y migrar opciones de categoría a Bottom Sheet ergonómico.
  - [x] Pulir barra de filtros y `RepaintBoundary` en `ResponsibilitiesScreen`.

- [x] **T4 — Subagente 4 (`agent/ui/chat-ajustes-y-tipografia` @ `4be4c54`):**
  - [x] Reemplazar las 96 llamadas fantasma a `GoogleFonts.outfit(...)` en `lib/Screens/ai_chat_screen.dart` por `TextStyle` nativo 100% offline con `tabularFigures` en montos.
  - [x] Pulir `lib/widgets/moneo_header_bar.dart` (haptics en `MoneoSegmentedControl` y acabado limpio) y `lib/Screens/settings_screen.dart` (grupos fintech limpios sin alterar keys ni acciones).

- [x] **T5 — Integración, pruebas en Docker (`finazaap-flutter`) y handoff:**
  - [x] Consolidar las 4 ramas `agent/ui/*` en `integration/ui-pulido-y-fluidez` (`dabf29c` + `9622a71`).
  - [x] Ejecutar `dart analyze` (`0 errores`) y `flutter test --no-pub -j 1` completo en Docker (**378/378 pasaron**).
  - [x] Recompilar APK `prod` release limpio en Docker tras `flutter clean` (`7f08ea6890550f87863ea52518fccb6e398f8e5c593d1ed81885ea6fa1119c0d`, `libapp.so`: `eb0ad2fbbddd7ba0d9e958b26dd201a479aad2d95d90c6c138cddd4a4d1f5b5b`) y actualizar `docs/handoff/`.
