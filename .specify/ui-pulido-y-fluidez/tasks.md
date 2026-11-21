# Tareas — `ui-pulido-y-fluidez`

- [x] **T0 — Spec Kit y rama de integración `integration/ui-pulido-y-fluidez`:**
  - [x] Crear rama `integration/ui-pulido-y-fluidez` desde `integration/notificaciones-rag-y-multi-ia` (`21ece12`).
  - [x] Escribir `spec.md`, `plan.md` y `tasks.md`.

- [ ] **T1 — Subagente 1 (`agent/ui/motion-y-navegacion`):**
  - [ ] Añadir `textTheme`, `pageTransitionsTheme`, `bottomSheetTheme`, `dialogTheme` y `snackBarTheme` en `lib/themes/app_theme_data.dart` preservando intactos los tokens de color de los 4 temas.
  - [ ] Extender `MoneoSpringMotion` y `MoneoPressableScale` a los 4 temas (manteniendo `LiquidGlassSurface` con `BackdropFilter` exclusivo de `Diurno`).
  - [ ] Unificar scroll limpio en `lib/main.dart`, añadir cross-fade suave + haptics + `RepaintBoundary` en `MainContainer` y `CustomPillBottomNavBar`, y eliminar `BackdropFilter` + anclar en zona del pulgar en `FloatingActionMenuScreen`.

- [ ] **T2 — Subagente 2 (`agent/ui/home-y-balance-fintech`):**
  - [ ] Rediseñar `TotalBalanceWidget` (anillo custom redondeado y animado, menos cajas anidadas, selector mes/año en Bottom Sheet sin `BackdropFilter`).
  - [ ] Optimizar `Home` (eliminar doble rebuild, `AnimatedSize` + `AnimatedRotation` en secciones de fecha, tarjeta contraída compacta y filas de transacción limpias).
  - [ ] Modernizar `TransactionListWidget` eliminando colores/sombras hardcodeados heredados.

- [ ] **T3 — Subagente 3 (`agent/ui/modales-fluidez-y-pantallas`):**
  - [ ] Eliminar los `BackdropFilter` pesados en `categories_screen.dart`, `responsibilities_screen.dart`, `selecctaccount.dart`, `annual_projection_screen.dart`, `account_dialogs.dart`, `add_account_dialogs.dart`, `edit_account_dialogs.dart`, `add_responsibility_dialog.dart`, `responsibility_actions_menu.dart` y `correction_dialog.dart`.
  - [ ] Corregir parpadeo de spinner en `CategoriesScreen` al cambiar de pestaña y migrar opciones de categoría a Bottom Sheet ergonómico.
  - [ ] Pulir barra de filtros y `RepaintBoundary` en `ResponsibilitiesScreen`.

- [ ] **T4 — Subagente 4 (`agent/ui/chat-ajustes-y-tipografia`):**
  - [ ] Reemplazar las 96 llamadas fantasma a `GoogleFonts.outfit(...)` en `lib/Screens/ai_chat_screen.dart` por `TextStyle` nativo 100% offline con `tabularFigures` en montos.
  - [ ] Pulir `lib/widgets/moneo_header_bar.dart` (haptics en `MoneoSegmentedControl` y acabado limpio) y `lib/Screens/settings_screen.dart` (grupos fintech limpios sin alterar keys ni acciones).

- [ ] **T5 — Integración, pruebas en Docker (`finazaap-flutter`) y handoff:**
  - [ ] Consolidar las 4 ramas `agent/ui/*` en `integration/ui-pulido-y-fluidez`.
  - [ ] Ejecutar `dart analyze` y `flutter test --no-pub -j 1` completo en Docker + nuevas pruebas de regresión UI/fluidez.
  - [ ] Recompilar APK `prod` release en Docker con hashes verificados y actualizar `docs/handoff/`.
