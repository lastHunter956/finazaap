# Desglose de Tareas — `ui-temas-y-asistente`

## Fase 1: Tokens y Contraste (Actual)
- [x] Crear rama de agente `agent/ui/fase-1-tokens-contraste` desde `main`.
- [x] Redactar `.specify/ui-temas-y-asistente/{spec.md,plan.md,tasks.md}`.
- [x] Actualizar `_diurno`, `_dia`, `_nocturno` (Dracula) y `onSecondary` en `lib/themes/app_theme_data.dart` manteniendo `_defaultDark` intacto.
- [x] Corregir colores hardcodeados y contraste de etiquetas pequeñas/botones en `lib/widgets/total_balance_widget.dart`.
- [x] Corregir textos blancos fijos en diálogos de `lib/Screens/settings_screen.dart`.
- [x] Corregir colores blancos fijos en gráfica `_buildBarChart` de `lib/Screens/statistics.dart`.
- [x] Ajustar borde y sombra en `lib/widgets/custom_pill_bottom_nav_bar.dart` (sin glass/blur aún).
- [x] Crear `test/themes/app_theme_contrast_test.dart` para verificar valores Dracula, preservación de `Default` y ratios WCAG 2.1.
- [x] Ejecutar `dart analyze` y `flutter test -j 1` en Docker (`finazaap-flutter`).
- [x] Consolidar en `integration/ui-temas-y-asistente` sin hacer merge a `main` y actualizar `docs/handoff/`.
- [ ] **Esperar validación visual del usuario antes de Fase 2.**

## Fase 2: Asistente Financiero (`AiChatScreen`) — Pendiente
- [ ] Corregir bug del `Spacer()` en burbujas y adoptar ancho orgánico.
- [ ] Eliminar colores hardcodeados y bordes neón fijos en `AiChatScreen`.
- [ ] Unificar las 3 barras superiores en cabecera única.
- [ ] Implementar composer flotante (paleta Dracula en `Nocturno`, sin glass en Fase 2).
- [ ] Tematizar tarjetas de sugerencias y unificar divisa con `CurrencyHelper`.

## Fase 3: Liquid Glass en `Diurno` — Pendiente
- [ ] Aplicar `BackdropFilter` / `ImageFiltered` moderado en `Diurno` solo para `CustomPillBottomNavBar` y composer de `AiChatScreen`, con variante sólida de respaldo.
- [ ] Validar rendimiento y legibilidad en `Samsung SM_S721B`.
