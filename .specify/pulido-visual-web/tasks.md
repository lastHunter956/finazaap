# Tareas Verificables — Pulido Visual Incremental Web (`pulido-visual-web`)

## Lote P0 — Accesibilidad, Contraste, Tokens y Semántica (Agente A)
- [ ] **P0.1:** Actualizar `_defaultDark` en `lib/themes/app_theme_data.dart` (`textHint: 0xFF90A0B5`, `secondaryAccent: 0xFF6B9EFF`, `expense: 0xFFFF6B6B`, `error: 0xFFFF6B6B`) y validar los 4 temas en `test/themes/app_theme_contrast_test.dart`.
- [ ] **P0.2:** Subir targets táctiles a `>= 44–48 dp` y agregar `Semantics` + `Tooltip` en `MoneoHeaderBar` (`_HeaderBackButton`), `Home`, `AiChatScreen`, `SelectAccountScreen`, `PinCodeScreen`, `SettingsScreen`, `PendingTransactionCard` y controles de filtros.
- [ ] **P0.3:** Reemplazar colores hardcodeados (`Colors.green/red/blue/amber/white`) por tokens `context.appTheme` + `AppColors.getReadableColor`, unificar radios con `AppSizes` y reducir sombras apiladas a 1 sombra sutil en pantallas/widgets (sin tocar `statistics.dart`).
- [ ] **P0.4:** Agregar/ejecutar tests de contraste, `Semantics` y `360×640 @ 1.35x`, más `dart analyze` + `flutter test --no-pub -j 1` + `flutter build web`.

## Lote P1 — Home y Transacciones (Agente B)
- [ ] **P1.1:** Simplificar `TotalBalanceWidget` (saldo `"Disponible"` 32–36px tabular, menor anidación, anillo robusto ante exceso, quitar botones de filtro internos).
- [ ] **P1.2:** Simplificar `Home` (jerarquía clara, `MoneoSegmentedControl` junto al historial, cabeceras de fecha legibles, filas con ícono coloreado por categoría real + nombre + hora `HH:mm`/cuenta + monto tabular, y estado vacío con CTA).
- [ ] **P1.3:** Agregar/actualizar widget tests de `Home` y `TotalBalanceWidget` (`360×640 @ 1.35x`, vacío, filtros, color de categoría) y validar suite completa + `flutter build web`.

## Lote P2 — Estados Vacíos y Overflows `1.35x` (Agente C)
- [ ] **P2.1:** Añadir estados vacíos accionables con CTA en `SelectAccountScreen`, `ResponsibilitiesScreen` y `AnnualProjectionScreen`.
- [ ] **P2.2:** Eliminar riesgos de `RenderFlex overflow` a `360×640 @ 1.35x` en `SelectAccountScreen`, `DailyTransactionsScreen`, `ResponsibilitiesScreen` (`_StickyCategoryDelegate`), `ResponsibilityListItem`, `PendingTransactionCard`, `FloatingActionMenuScreen`, `ResponsibilityActionsMenu`, `PinCodeScreen`, y eliminar doble padding en `AnnualProjectionScreen`.
- [ ] **P2.3:** Agregar widget tests `360×640 @ 1.35x` para `SelectAccountScreen`, `DailyTransactionsScreen`, `ResponsibilitiesScreen`, `PendingTransactionCard`, `PinCodeScreen`, `SettingsScreen` y validar suite completa + `flutter build web`.

## Lote D — Integración, Build Web y Verificación Visual
- [ ] **D.1:** Verificar diff completo en `integration/pulido-visual-web` (`statistics.dart` intacto, archivos protegidos intactos, `main` intacto).
- [ ] **D.2:** Ejecutar `dart analyze --no-fatal-warnings lib/ test/` (0 errores) y `flutter test --no-pub -j 1` (100% verde) en Docker.
- [ ] **D.3:** Ejecutar `flutter build web --no-pub --no-tree-shake-icons` y verificar visualmente la app compilada en navegador headless/Chrome (jerarquía, contraste en los 4 temas, `360×640` a `1.35x`, estados vacíos).
