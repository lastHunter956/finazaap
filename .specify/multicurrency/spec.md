# Spec: Soporte Multimoneda en Moneo (`agent/currency/multi-currency`)

## 1. Estado Existente (Verificado)
- `lib/utils/currency_helper.dart`: soporta 12 monedas (`USD`, `MXN`, `PEN`, `GBP`, `COP`, `ARS`, `BRL`, `UYU`, `VES`, `CLP`, `EUR`, `JPY`) con formato y parseo dependientes de una sola moneda global (`default_currency` en `SharedPreferences`).
- `lib/data/models/account_item.dart`: no persiste `currencyCode` propio aún.
- `lib/data/model/add_date.dart` (`Add_data`) y `lib/data/model/responsibility.dart` (`Responsibility`): no persisten `currencyCode` propio aún (sus adaptadores `.g.dart` están protegidos).
- `lib/Screens/home.dart`, `lib/Screens/selecctaccount.dart`, `lib/widgets/total_balance_widget.dart`, `lib/data/transaction_service.dart` (protegido) y `lib/data/credit_card_calculator.dart` (protegido): suman cuentas y movimientos como si compartieran una única moneda global.

## 2. Decisión de Producto y Reglas
- La aplicación debe soportar múltiples monedas y cada cuenta debe tener una moneda explícita.
- Conservar y reutilizar `CurrencyHelper` y el soporte existente sin romper compatibilidad.
- **Prohibido sumar monedas distintas como si fueran equivalentes.**
- Sin conversión aprobada, presentar totales separados por moneda.
- No inventar tasas de cambio ni reinterpretar importes existentes.

## 3. Alcance Autorizado en Esta Rama
1. **Capa pura de monedas (`lib/utils/currency_helper.dart`):**
   - Exponer catálogo (`supportedCurrencies`, `isSupported`, `normalizeCode`) y utilidades por moneda (`symbolFor`, `decimalDigitsFor`, `usesCommaDecimalFor`, `formatFor`, `formatStringFor`, `formatCompactFor`, `cleanAmountStringFor`) sin mutar `_cachedCurrency`.
   - Soportar `currencyCode` opcional en `ThousandsSeparatorInputFormatter`.
   - Agregar `MultiCurrencyTotals` para acumular totales agrupados por moneda explícita sin mezclar monedas distintas, y `canTransferBetweenCurrencies` para validar compatibilidad de moneda en transferencias sin conversión aprobada.
2. **Presentación de totales separados por moneda (`lib/widgets/total_balance_widget.dart`, `lib/Screens/home.dart`, `lib/Screens/selecctaccount.dart`):**
   - Permitir que `TotalBalanceWidget` reciba totales opcionales separados por moneda (`availableBalancesByCurrency`, `accountingBalancesByCurrency`, `expensesByCurrency`, `incomeByCurrency`), conservando la apariencia actual cuando hay una sola moneda y mostrando líneas/etiquetas separadas por moneda cuando hay múltiples monedas.
   - En `Home` y `SelecctAccount`, leer un posible `currencyCode` en los mapas JSON de cuentas (con fallback de lectura a `CurrencyHelper.currencyCode` sin modificar esquemas persistidos ni migrar datos) para construir `MultiCurrencyTotals` sin sumar monedas distintas.
3. **Pruebas sintéticas:**
   - Unit tests para `CurrencyHelper` multimoneda, `ThousandsSeparatorInputFormatter(currencyCode: ...)`, `MultiCurrencyTotals` y `canTransferBetweenCurrencies`.
   - Widget/unit tests para `TotalBalanceWidget` con múltiples monedas separadas.

## 4. Bloqueos Aislados (Requieren Aprobación Explícita / Cambio de Esquema)
- **Persistencia de `currencyCode` en esquemas y migración:**
  - `AccountItem` (`SharedPreferences` `'accounts'`), `Add_data` (`@HiveField` + `add_date.g.dart` protegido), `Responsibility` (`@HiveField` + `responsibility.g.dart` protegido).
- **Archivos protegidos:**
  - `lib/data/transaction_service.dart`: `_updateGlobalBalance` multimoneda y bloqueo/conversión de transferencias entre monedas distintas.
  - `lib/data/credit_card_calculator.dart`: precisión y validación por moneda de tarjeta.
  - `lib/data/model/*.g.dart`: regeneración con `build_runner` tras aprobar nuevos `@HiveField`.
- **UI de alta/edición dependiente de esquema:**
  - Selector obligatorio de moneda en `AddAccountDialog` / `EditAccountDialog` y asignación en `AddScreen` / `AddExpenseScreen` / `TransferScreen` / `ResponsibilitiesScreen` / notificaciones una vez autorizado el esquema persistido.
