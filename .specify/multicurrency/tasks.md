# Tasks: Soporte Multimoneda (`agent/currency/multi-currency`)

1. [x] Crear worktree aislado y verificar ejecución de pruebas en Docker sobre el worktree.
2. [x] Registrar alcance (`spec.md`, `plan.md`, `tasks.md`) en `.specify/multicurrency/`.
3. [x] Implementar API multimoneda pura, `ThousandsSeparatorInputFormatter(currencyCode: ...)`, `MultiCurrencyTotals` y `canTransferWithoutConversion` en `lib/utils/currency_helper.dart`.
4. [x] Soportar totales separados por moneda en `lib/widgets/total_balance_widget.dart`, `lib/Screens/home.dart` y `lib/Screens/selecctaccount.dart` (solo lectura de `currencyCode` opcional con fallback, sin cambiar esquemas persistidos).
5. [x] Agregar pruebas unitarias y de widget sintéticas en `test/currency/multi_currency_test.dart`.
6. [x] Ejecutar `dart analyze` y `flutter test --no-pub -j 1` en Docker sobre el worktree y consolidar commits locales.
