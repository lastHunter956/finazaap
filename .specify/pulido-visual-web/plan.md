# Plan Técnico — Pulido Visual Incremental Web (`pulido-visual-web`)

> **Rama de integración:** `integration/pulido-visual-web` (base `c432642`)
> **Worktree:** `/Volumes/ADATA SD620/Programacion 7.0/moneo/wt-pulido-visual`

---

## 1. Estrategia por Lotes y Ramas de Agente

Cada lote se implementa en su propia rama/worktree de agente (`agent/ui/*`) partiendo de la integración verificada en verde del lote anterior, consolidando secuencialmente en `integration/pulido-visual-web`:

1. **Lote P0 (`agent/ui/p0-accesibilidad-tokens` — Agente A):**
   - `lib/themes/app_theme_data.dart` (solo `_defaultDark`: `textHint: 0xFF90A0B5`, `secondaryAccent: 0xFF6B9EFF`, `expense: 0xFFFF6B6B`, `error: 0xFFFF6B6B`) + `test/themes/app_theme_contrast_test.dart` (verificar AA `>= 4.5:1` en las 3 superficies para los 4 temas).
   - `lib/widgets/moneo_header_bar.dart`: `_HeaderBackButton` con hit target `48×48` y `Semantics(button: true, label: 'Volver')` + `Tooltip`.
   - `lib/widgets/floating_action_menu.dart` & `lib/widgets/floating_action_menu_screen.dart`: migración a `context.appTheme.*`, contraste AA en botones/flechas y `AppSizes`.
   - `lib/Screens/pin_code_screen.dart`: `Semantics` en teclado numérico/borrar/biometría, contraste AA con `context.appTheme` o valores accesibles.
   - `lib/Screens/ai_chat_screen.dart`: hit targets `>= 44–48dp` y `Semantics` en botón Atrás, enviar/detener, selector de motor y sugerencias.
   - `lib/Screens/selecctaccount.dart`, `lib/Screens/categories_screen.dart`, `lib/Screens/responsibilities_screen.dart`, `lib/Screens/annual_projection_screen.dart`, `lib/Screens/daily_transactions.dart`, `lib/Screens/settings_screen.dart`, `lib/Screens/add.dart`, `lib/Screens/add_expense.dart`, `lib/Screens/transfer.dart`, `lib/features/notifications/presentation/widgets/suspicious_badge.dart`, `lib/widgets/urgent_payments_section.dart`, `lib/widgets/responsibility_dashboard_card.dart`, `lib/widgets/responsibility_list_item.dart`, `lib/widgets/show_transaction_options.dart`, `lib/widgets/responsibility_actions_menu.dart`: eliminar colores hardcodeados incompatibles, unificar radios con `AppSizes` y sombras a 1 sombra sutil, añadir `Semantics` y targets `>= 44×44`.
2. **Lote P1 (`agent/ui/p1-home-transacciones` — Agente B):**
   - `lib/widgets/total_balance_widget.dart`: saldo `"Disponible"` hero (`32–34px`, `tabularFigures`), reducción de cajas/botones internos, anillo robusto cuando `expenses > income`, retiro de botones de filtro internos hacia `Home`.
   - `lib/Screens/home.dart`: reducir acciones competidoras, colocar `MoneoSegmentedControl` (`Todos`/`Gastos`/`Ingresos`) junto a `"Historial de transacciones"`, agrupar por fecha legible (`Hoy · ...`, `Ayer · ...`, `dd MMM`), usar `_categoryColors` real con `AppColors.getReadableColor` en el ícono de cada fila, mostrar `HH:mm` + cuenta/ruta en la fila, y agregar estado vacío accionable con CTA `"Registrar movimiento"`.
3. **Lote P2 (`agent/ui/p2-vacios-overflows` — Agente C):**
   - Estados vacíos con CTA en `selecctaccount.dart`, `responsibilities_screen.dart` y `annual_projection_screen.dart`.
   - Corrección de overflows a `360×640 @ 1.35x` en `TotalBalanceWidget`, `SelectAccountScreen`, `DailyTransactionsScreen`, `ResponsibilitiesScreen`, `ResponsibilityListItem`, `PendingTransactionCard`, `FloatingActionMenuScreen`, `ResponsibilityActionsMenu`, `PinCodeScreen`, `AnnualProjectionScreen` (quitar padding duplicado).
4. **Consolidación y Validación Final (Agente D):**
   - Consolidar en `integration/pulido-visual-web`, limpiar ramas/worktrees temporales `agent/ui/*`, ejecutar `dart analyze` (0 errores), `flutter test --no-pub -j 1` completo en Docker y `flutter build web --no-pub --no-tree-shake-icons` + inspección visual en navegador sin tocar `main`.
