# Desglose de Tareas — `ui-temas-y-asistente`

## Fase 1: Tokens, Contraste Estricto y Material Liquid Glass
- [x] Crear rama de agente `agent/ui/fase-1-tokens-contraste` desde `main`.
- [x] Verificar matemáticamente ratios WCAG 2.1 sobre `primaryBackground`, `cardBackground` y `darkBackground`.
- [ ] Corregir `_nocturno`, `_diurno` y `_dia` en `lib/themes/app_theme_data.dart` para que todo texto normal y estado semántico alcance `>= 4.5:1` sobre sus 3 superficies, conservando `_defaultDark` intacto.
- [ ] Implementar `isDiurno` y `LiquidGlassSurface` en `lib/themes/app_theme_data.dart` con respaldo de accesibilidad Apple HIG (*Reduce Transparency / Increase Contrast*).

## Fase 2: Navegación, Controles Diurno (Apple HIG) y Ajustes
- [ ] Activar `extendBody` condicional en `lib/Screens/main_container.dart` para `Diurno`.
- [ ] Aplicar `LiquidGlassSurface` y lente activa en `lib/widgets/custom_pill_bottom_nav_bar.dart` solo en `Diurno`.
- [ ] Refinar acabado Apple sin blur y corregir colores hardcodeados restantes en `lib/Screens/home.dart` y `lib/widgets/total_balance_widget.dart`.
- [ ] Eliminar `"Bandeja de Notificaciones (Demo Dev)"` en `lib/Screens/settings_screen.dart` y refinar selector en `Diurno`.

## Fase 3: Rediseño Integral del Asistente Financiero (`AiChatScreen`)
- [ ] Migrar 100% `lib/Screens/ai_chat_screen.dart` de `AppColors.*` y hex hardcodeados a `context.appTheme`.
- [ ] Unificar cabecera (`título` + `Simulador/Gemma IA` + `Consultas/Perfil Cognitivo`) con `LiquidGlassSurface` en `Diurno`.
- [ ] Corregir bug del `Spacer()` en burbujas, implementar ancho orgánico y eliminar bordes neón fijos.
- [ ] Implementar composer flotante (con `LiquidGlassSurface` solo en `Diurno`), soporte de teclado abierto y textos largos.
- [ ] Unificar moneda con `CurrencyHelper.format(...)` y tematizar sugerencias + diálogos de edición + tab `Perfil Cognitivo`.

## Validación y Entrega en Integración
- [ ] Ampliar `test/themes/app_theme_contrast_test.dart` (WCAG 2.1 AA/AAA estricto, exclusividad de glass en `Diurno`, ancho orgánico y responsividad de `AiChatScreen` en móvil + teclado abierto en los 4 temas).
- [ ] Ejecutar `dart analyze` y `flutter test -j 1` en Docker (`finazaap-flutter`).
- [ ] Consolidar en `integration/ui-temas-y-asistente`, actualizar `docs/handoff/` y recargar el servidor web debug en puerto `8080`.
- [ ] **Esperar validación visual humana antes de cualquier merge a `main` o instalación en teléfono.**
