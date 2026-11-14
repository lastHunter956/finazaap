# Plan: Soporte Multimoneda Compatible (`agent/currency/multi-currency`)

## 1. Estrategia de Aislamiento y Compatibilidad
- Trabajar exclusivamente en el worktree `/Volumes/ADATA SD620/Programacion 7.0/moneo/wt-multicurrency` (rama `agent/currency/multi-currency` basada en `main` @ `04682e1`).
- No modificar archivos protegidos, `pubspec.yaml`, `pubspec.lock`, `docs/handoff/` ni `docs/audit/` (evitando escrituras solapadas con el chat de consolidación).
- Conservar al 100% las firmas actuales de `CurrencyHelper`, `TotalBalanceWidget` y `AccountItem`.

## 2. Diseño Técnico
1. **`lib/utils/currency_helper.dart`:**
   - Añadir helpers puros parametrizados por `currencyCode`:
     - `supportedCurrencies`, `isSupported(String? code)`, `normalizeCode(String? code, {String? fallback})`
     - `symbolFor(String? code)`, `decimalDigitsFor(String? code)`, `usesCommaDecimalFor(String? code)`
     - `formatFor(double amount, String? currencyCode, {bool showSymbol = true, int? decimalDigits})`
     - `formatStringFor(String amountStr, String? currencyCode, {bool showSymbol = true, int? decimalDigits})`
     - `formatCompactFor(double amount, String? currencyCode, {bool showSymbol = true})`
     - `cleanAmountStringFor(String amountStr, {String? currencyCode})`
   - Refactorizar `format`, `formatCompact`, `getFormatter`, `usesCommaDecimal`, `cleanAmountString` para delegar en las variantes `*For(..., _cachedCurrency)` (DRY-first, sin duplicación).
   - Añadir `final String? currencyCode;` opcional a `ThousandsSeparatorInputFormatter`.
   - Añadir `MultiCurrencyTotals` (inmutable/builder ligero sobre `Map<String, double>` agrupado por código de moneda normalizado, orden determinista con moneda principal primero, `formatLines()` / `formatSummary()`, y helper `canTransferWithoutConversion(String? fromCurrency, String? toCurrency)`).
2. **`lib/widgets/total_balance_widget.dart`:**
   - Añadir propiedades opcionales:
     - `Map<String, double>? availableBalancesByCurrency`
     - `Map<String, double>? accountingBalancesByCurrency`
     - `Map<String, double>? expensesByCurrency`
     - `Map<String, double>? incomeByCurrency`
   - Si alguno tiene `> 1` moneda, renderizar los montos separados por moneda (ej. `$ 1.000.000,00 COP` / `$250.00 USD`) sin sumarlos. Si hay `<= 1` moneda o son `null`, conservar el renderizado actual intacto.
3. **`lib/Screens/home.dart` y `lib/Screens/selecctaccount.dart`:**
   - En `home.dart` (`_updateAvailableBalance` y cálculo de balances por cuenta/transacción si aplica): leer `data['currencyCode']` (con fallback a `CurrencyHelper.currencyCode` sin escribir en disco) para poblar `MultiCurrencyTotals` y pasarlo a `TotalBalanceWidget`.
   - En `selecctaccount.dart` (`_calculateTotalBalancesByCurrency`): agrupar saldos de cuentas incluidas no-TC por `currencyCode` (fallback `CurrencyHelper.currencyCode`) y mostrar totales separados por moneda en el encabezado de resumen cuando haya más de una moneda.
4. **Pruebas:**
   - `test/currency/multi_currency_test.dart` cubriendo `CurrencyHelper.*For`, `ThousandsSeparatorInputFormatter(currencyCode: ...)`, `MultiCurrencyTotals` (no suma monedas distintas, orden, formato por moneda), `canTransferWithoutConversion` y `TotalBalanceWidget` multimoneda.
