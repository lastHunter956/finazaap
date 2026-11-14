# Desglose de Tareas — `ui-temas-y-asistente`

## Fase 1: Tokens, Contraste Estricto y Material Liquid Glass
- [x] Crear rama de agente `agent/ui/fase-1-tokens-contraste` desde `main`.
- [x] Verificar matemáticamente ratios WCAG 2.1 sobre `primaryBackground`, `cardBackground` y `darkBackground`.
- [x] Corregir `_nocturno`, `_diurno` y `_dia` en `lib/themes/app_theme_data.dart` para que todo texto normal y estado semántico alcance `>= 4.5:1` sobre sus 3 superficies, conservando `_defaultDark` intacto.
- [x] Implementar `isDiurno` y `LiquidGlassSurface` en `lib/widgets/liquid_glass_surface.dart` (re-exportado en `app_theme_data.dart`) con respaldo de accesibilidad Apple HIG (*Reduce Transparency / Increase Contrast*).

## Fase 2: Navegación, Controles Diurno (Apple HIG) y Ajustes
- [x] Activar `extendBody` condicional en `lib/Screens/main_container.dart` para `Diurno` con propagación real vía `MoneoNavBarScope` y `effectiveBottomClearance`.
- [x] Aplicar `LiquidGlassSurface`, cápsula proporcional dinámica y `SpringSimulation` en `lib/widgets/custom_pill_bottom_nav_bar.dart` solo en `Diurno`.
- [x] Refinar acabado Apple sin blur y corregir colores hardcodeados restantes en `lib/Screens/home.dart` y `lib/widgets/total_balance_widget.dart`.
- [x] Eliminar `"Bandeja de Notificaciones (Demo Dev)"` en `lib/Screens/settings_screen.dart` y refinar selector en `Diurno`.

## Fase 3 y 4: Asistente Editorial, Perfil Cognitivo, Encabezados Unificados y Clearance en 13 Pantallas
- [x] Migrar 100% `lib/Screens/ai_chat_screen.dart` de `AppColors.*` y hex hardcodeados a `context.appTheme`.
- [x] Rediseñar burbujas con estilo editorial limpio, ancho orgánico sin `Spacer()`, cero `BackdropFilter` en contenido y tarjetas estructuradas solo para sugerencias accionables.
- [x] Rediseñar `Perfil Cognitivo` eliminando truncamientos `.substring(0, 12)` y marcas decorativas, con cuadrícula adaptativa a ancho y `TextScaler`.
- [x] Unificar `MoneoHeaderBar` (`primaryTab`, `subScreen`, `form`) y `MoneoSegmentedControl` en todas las pantallas (13 pantallas) con `MoneoLayoutMetrics.scrollBottomPadding` y `TextStyle` 100% offline.

## Validación y Entrega en Integración
- [x] Separar pruebas de contraste (`test/themes/app_theme_contrast_test.dart`) de las pruebas de layout/navegación/chat (`test/widgets/ui_layout_and_navigation_test.dart`).
- [x] Ejecutar `dart analyze` y `flutter test --no-pub -j 1` (**104/104** pruebas pasando) en Docker (`finazaap-flutter`).
- [x] Consolidar worktrees en `integration/ui-temas-y-asistente`, limpiar worktrees/ramas `agent/ui/*`, actualizar `docs/handoff/` y recargar el servidor web debug en puerto `8080`.
- [ ] **Esperar validación visual humana antes de cualquier merge a `main` o instalación en teléfono.**
