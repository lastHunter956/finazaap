# Punto de Continuidad (`docs/audit/CONTINUITY_STATE.md`)

> **Fecha:** 2026-11-14  
> **Estado de cuota:** No consultable desde herramientas (no se inventa valor numérico).  
> **Rama / Commit base:** `main` @ `bab211fcc9243e89b050fd1a40cb9c25157d7fcb` (`bab211f`), árbol limpio salvo `?? docs/audit/`.  
> **Agentes / Tareas activas:** 0 subagentes activos, 0 tareas en segundo plano.

---

## 1. Solicitud Original y Alcance
- **Fase 1 (Auditoría):** Auditoría de solo lectura en 4 frentes de Moneo (`finazaap`): (1) lógica y contabilidad, (2) fluidez y rendimiento, (3) modelo IA on-device (`flutter_gemma` / por qué tarda o falla en el teléfono), y (4) seguridad integral.
- **Fase 2 (Paquete de Ejecución):** Convertir los hallazgos en un paquete verificable en `docs/audit/` para ejecutar en otro chat (con este mismo modelo y multiagente controlado, máx. 2 subagentes simultáneos heredando modelo), **sin modificar código, configuración, dependencias ni archivos protegidos**.

---

## 2. Base de Git y Relación con UI (`integration/ui-temas-y-asistente`)
- `integration/ui-temas-y-asistente` (incluyendo `af1fbf5`) ya está fusionada por `--ff-only` en `main` (`bab211f`) y retirada.
- Modificó 28 archivos entre `165c1c1..bab211f`. Los puntos de mayor riesgo de conflicto para futuras tareas son: `lib/Screens/ai_chat_screen.dart`, `lib/Screens/home.dart`, `lib/widgets/total_balance_widget.dart`, `lib/Screens/statistics.dart`, `lib/Screens/main_container.dart`.
- **Regla UI:** No alterar `app_theme_data.dart`, `liquid_glass_surface.dart`, `moneo_header_bar.dart`, `custom_pill_bottom_nav_bar.dart` ni sus tests.

---

## 3. Estado Real de Verificación (Lectura vs Reporte vs Reproducción)
- **Confirmados por lectura directa en código / pub-cache:**
  - `flutter_gemma: 1.0.2` (`pubspec.lock`), soporte de `ModelType.gemma4` (`model.dart:4`), `maxTokens` = KV-cache total con mínimo `1024` (`litert_lm_engine.dart:27-34`), `createChat()` cierra sesión previa (`ffi_inference_model.dart:115,305`) y `addQueryChunk` concatena texto en `.litertlm` Android (`extensions.dart:80-84`, `ffi_inference_model.dart:369-375`).
  - `assets/models/gemma.litertlm` = `2.4G` (`2,588,147,712` bytes) no incluido en `pubspec.yaml:81-83`; `MainActivity.kt` reporta `totalMem`; `AndroidManifest.xml` principal y plugins de pub-cache no declaran `INTERNET` ni `allowBackup="false"`.
  - Muestras directas en código de: `M1`–`M10`, `SEC-01`–`SEC-13` (con matiz en `SEC-01`: 4 cajas de notificaciones sí usan `HiveAesCipher`, `data`/`responsibilities`/`SharedPreferences` no), `L1.1`–`L1.13`, `L2.1`–`L2.6`, `L3.1`–`L3.5`, `L4.1`–`L4.6`, `L5.1`–`L5.4`, `P1.1`–`P1.3`, `P2.1` (bajada a ALTO por ser animación única de 20 s), `P2.2`, `P3.1`, `P3.2`.
- **Hipótesis pendientes (NO verificadas en ejecución real / dispositivo físico):**
  - Merged manifest real de `--release` (no existe `build/app/intermediates/merged_manifests/release/AndroidManifest.xml` en disco; se verificará en `T0.2`).
  - Todas las cifras de tiempos en segundos/ms, FPS y `tokens/s` son **estimaciones**, NO mediciones en dispositivo físico.
  - Estado real de los datos instalados en el teléfono (`R5CY21GE9YY`).
- **Fallos reproducidos con pruebas:** **0** hasta ejecutar `T0.1` (`test/audit/accounting_repro_test.dart`).
- **Hallazgos descartados:** **0** hasta la fecha (`P1.4`, `P2.3`, `P2.4`, `P3.3`, `P3.5` fueron confirmados por lectura directa en el último lote, corrigiendo `add_expense.dart:767` y `home.dart:1608,1633`).

---

## 4. Resultados de Ola 0 (`T0.1` y `T0.2` — Cerrada)
- **Rama y commit documental:** `docs/audit-execution-package` @ `88d5979` (base `main` @ `bab211f`).
- **Montaje Docker verificado:** `finazaap-flutter` monta `/Volumes/ADATA SD620/Programacion 7.0/moneo/finazaap -> /app` en la rama `docs/audit-execution-package`.
- **Baseline (`T0.2`):**
  - `docker-compose exec -T flutter-env dart analyze` → salida `2` (`1006 issues`: `0` errors, `96` warnings, `910` infos). Log: `docs/audit/logs/t0_2_baseline_analyze.log`.
  - `docker-compose exec -T flutter-env flutter test --no-pub -j 1` → salida `0` (`104/104 All tests passed!`). Log: `docs/audit/logs/t0_2_baseline_test.log`.
- **Manifest Release (`T0.2`):**
  - **Bloqueado en entorno Gradle offline:** `./gradlew :app:processReleaseMainManifest --offline --no-daemon` falló (`RC=1`); permiso `INTERNET` en variante release **no determinado**.
  - **Versiones efectivas:** Flutter `3.44.2` (Dart `3.12.2`), Java `OpenJDK 17.0.19`, Gradle `8.7`, AGP `8.6.0`, Kotlin plugin `2.1.0` en `android/settings.gradle:22` forzado a `1.9.22` en `android/build.gradle:2,15`. Error: `Your project's Kotlin version (1.9.22) is lower than Flutter's minimum supported version of 2.0.0.` (Log: `docs/audit/logs/t0_2_release_manifest_gradle.log`).
  - Se creó la tarea separada [T0.3](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/audit/tasks/T0.3-desbloqueo-kotlin-gradle-android.md) para resolver este bloqueo con aprobación.
- **Suite de reproducción aislada (`T0.1` — `docs/audit/repro/accounting_repro_test.dart`):**
  - `dart analyze docs/audit/repro/accounting_repro_test.dart` → `0` issues (`RC=0`).
  - `flutter test --no-pub -j 1 docs/audit/repro/accounting_repro_test.dart` → `RC=1` (**7 fallaron reproduciendo defectos reales, 1 pasó**; log: `docs/audit/logs/t0_1_repro_test.log`).
  - **Reproducidos con prueba (7):** `L1.3a` (`5900000.0` vs `900000.0`), `L1.3b` (`10900000.0` vs `900000.0`), `L1.3c` (`15900000.0` vs `900000.0`), `L1.4` (`paidAmountThisMonth = 200000.0` vs `0.0`), `L2.4` (`100000.0` vs `0.0`), `L2.5` (`50000.0` vs `0.0`), `L1.10` (`10.0` vs `10000.0`).
  - **No reproducido en test unitario (1):** `L3.2` (`togglePaidStatus` **pasó** `updated.isPaid == true`; no se demostró el fallo en el escenario probado).
  - **Casos UI (`L1.1`, `L2.1`, `L3.1`):** Constructores públicos verificados (`DailyTransactionsScreen`, `AddExpenseScreen`, `ResponsibilitiesScreen`); son viables mediante `testWidgets` con `tester.runAsync` y almacenamiento sintético sin tocar `lib/`, pero quedaron pendientes para Ola 1 (`T1.3c`) por requerir montaje de tema y `SharedPreferences`.
  - **Política de `docs/audit/repro/`:** El baseline en `test/` (`104/104`) pasa **excluyendo** estos escenarios conocidos; esto no corrige los defectos ni demuestra aprobación integral. Cada prueba deberá trasladarse a `test/` al integrarse su corrección en Ola 1.

## 5. Progreso de Ola 1 — `T1.3a` (Completada en rama de tarea)
- **Rama:** `agent/ui/t1-3a-saldos` (desde `bc94ff7`).
- **Archivo protegido modificado (con autorización explícita):** `lib/data/transaction_service.dart` (`_updateGlobalBalance` excluye `includeInTotal == false` y tarjetas de crédito; `_revertTransaction` y `deleteTransaction` delegan en `_revertTransfer` con reversión simétrica en `ResponsibilityService` para tarjetas origen/destino).
- **Pruebas trasladadas a `test/`:** `test/audit/t1_3a_transaction_service_test.dart` (`5/5` pasan: `L1.3a`, `L1.3b`, `L1.3c`, `L1.4` y regresión normal de cuentas incluidas/transferencia líquida). Retiradas de `docs/audit/repro/accounting_repro_test.dart`.
- **Verificación en Docker (`finazaap-flutter` sobre `agent/ui/t1-3a-saldos`):**
  - `dart analyze lib/data/transaction_service.dart test/audit/t1_3a_transaction_service_test.dart` → `RC=2` (`0` errores; `7` warnings/infos preexistentes en `transaction_service.dart`, `0` issues en `t1_3a_transaction_service_test.dart`).
  - `flutter test --no-pub -j 1 test/audit/t1_3a_transaction_service_test.dart` → `RC=0` (`5/5`).
  - `flutter test --no-pub -j 1` → `RC=0` (`109/109`).
  - `flutter test --no-pub -j 1 docs/audit/repro/accounting_repro_test.dart` → `RC=1` (quedan `3` fallos conocidos: `L1.10`, `L2.4`, `L2.5`; `L3.2` pasa).
- **Caso de notificaciones `N1` (Completado en `agent/ui/notif-request-vs-approved`):** Solicitudes de pago descartadas como movimiento (`notification_parser.dart`), procedencia por `packageName` sin fallback a `accounts.first` y confirmación requerida ante múltiples productos o destino sin evidencia (`transaction_classifier.dart`, `notification_pipeline_service.dart`); pruebas trasladadas a `test/features/notifications/integration/notification_request_vs_completed_test.dart` (`7/7`, verificando también que `createTransaction=false` mantiene la propuesta en Pendientes sin alterar saldos).
- **Lote UI categorías en Pendientes + saldo en Cuentas (Completado en `agent/ui/pendientes-categorias-y-saldo-cuenta`):**
  - `CorrectionDialog` (`lib/features/notifications/presentation/widgets/correction_dialog.dart`) usa ahora `CategoryService.getCategoriesWithMetadata('Expenses'|'Income')` (misma fuente y criterio activo que `CategoriesScreen`), sin listas fijas alternativas ni creación silenciosa de categorías inexistentes; limpia selecciones inválidas al cambiar entre `gasto` e `ingreso` y mantiene `Transferir` sin forzar categoría de gasto.
  - `AddAccountDialog` (`lib/widgets/add_account_dialogs.dart`) y `EditAccountDialog` (`lib/widgets/edit_account_dialogs.dart`) dan una fila propia de ancho completo al campo `Saldo inicial` / `Saldo actual` / `Cupo total` conservando formato y lógica de guardado.
  - Pruebas en verde (`121/121` en `flutter test --no-pub -j 1`, incluyendo `correction_dialog_categories_test.dart` y `account_balance_field_layout_test.dart`).
- **Sublote A contabilidad TC (`L2.4` y `L2.5` en `agent/ui/credit-card-accounting-fixes` desde `c1c2f05`):**
  - `CreditCardCalculator.calculateMonthlyPayment` (`lib/data/credit_card_calculator.dart`) retorna `0.0` si `calculateTotalDebt(cardName) <= 0` (`L2.4`), conservando cuotas con intereses si existe deuda impaga.
  - `Responsibility.getDynamicQuota` y `Responsibility.getAmountForDate` (`lib/data/model/responsibility.dart`) retornan `0.0` para tarjetas si `CreditCardCalculator.calculateTotalDebt(safeName) <= 0` (`L2.5`), conservando `minimumPayment` cuando hay deuda activa.
  - Pruebas trasladadas a `test/audit/t1_3b_credit_card_calculator_test.dart` (`4/4`) y retiradas de `docs/audit/repro/accounting_repro_test.dart` (donde solo queda `L1.10` pendiente y `L3.2` no reproducido). Suite completa: `125/125` en Docker (`flutter test --no-pub -j 1`).
- **Sublote B contabilidad TC (`L2.1`, `L3.1` y regresiones Parte C en `agent/ui/credit-card-accounting-fixes`):**
  - `TransactionService._updateAccountBalance` (`lib/data/transaction_service.dart`) pasa a ser el único punto de sincronización de deuda y planes de cuotas para tarjetas (`processDebtIncrease`, `processDebtReversal`, `processDebtPayment`, `processPaymentReversal`), eliminando la llamada duplicada `ResponsibilityService.processDebtIncrease` en `AddExpenseScreen` (`lib/Screens/add_expense.dart`).
  - `ResponsibilitiesScreen._showUnifiedPaymentDialog` (`lib/Screens/responsibilities_screen.dart`) registra los pagos de obligaciones `tarjeta` como `Transfer` (`origen > tarjeta`) sin marcar `isObligationPayment` ni emitir `'Expenses'`, reduciendo la deuda en `CreditCardCalculator.calculateTotalDebt` y `cardBalance` de forma equivalente a una transferencia normal.
  - Regresiones Parte C en `test/audit/t1_3c_credit_card_flows_test.dart` (`5/5`): creación sin duplicación, edición con reversión de plan, eliminación con reversión de plan/mensualidad, transferencia desde/hacia TC vs pago directo y flujo widget `ResponsibilitiesScreen`. Suite completa: `130/130` en Docker (`flutter test --no-pub -j 1`).
- **Tarea `L1.10 / T1.1` (`CurrencyHelper` CLP en `agent/ui/t1-1-clp-currency` desde `00e26b2`):**
  - `CurrencyHelper` (`lib/utils/currency_helper.dart`) unifica `usesCommaDecimal` incluyendo `CLP` para `cleanAmountString` y `ThousandsSeparatorInputFormatter`, sin heurísticas nuevas ni migración de históricos.
  - Prueba `L1.10` trasladada de `docs/audit/repro/accounting_repro_test.dart` a `test/audit/t1_1_currency_helper_test.dart` (`3/3` pasando: lectura/edición/guardado CLP y regresiones para `COP`, `ARS`, `BRL`, `UYU`, `VES`, `EUR`, `USD`, `MXN`, `PEN`, `GBP`, `JPY`).
- **Tarea `T1.2` (`L3.3`, `L3.4`, `L3.5` en `agent/ui/t1-2-responsibility-frequencies` desde `6a8b7e2`):**
  - `L3.4`: eliminados `0.95`/`0.98` y liquidación `0 >= 0` en `ResponsibilityService` (`processDebtPayment`, `processPaymentReversal`, `registerPayment`, `revertPayment`, `createFromAccount`) mediante `Responsibility.isAmountCovered` a precisión decimal de la moneda activa (`CurrencyHelper`). Queda pendiente `credit_card_calculator.dart:193` (protegido, no autorizado en T1.2).
  - `L3.3`: `isPaidInMonth`, `isPaidOnDate`, `getDueDateForMonth` y `togglePaidStatus` corrigen ciclos `bimestral`/`trimestral`/`anual` con cambio de año, ocurrencias de `diario`/`semanal`/`quincenal` y ajuste de día 31 en febrero.
  - `L3.5`: `updateResponsibilityFromAccount` acepta `responsibilityId` opcional y normaliza búsqueda evitando duplicados y conservando historial. `L3.2` no reproducido (`responsibility.save()` intacto). Nota: los flujos reales UI (`selecctaccount.dart:255` -> `TransactionService.updateTransactionsAfterAccountEdit:551`) aún envían solo `oldName` (sin `responsibilityId`).
  - Pruebas en `test/audit/t1_2_responsibility_test.dart` (`7/7`) y verificación semántica financiera en `test/audit/t1_3b_credit_card_calculator_test.dart` (`8/8`).
- **Corrección acotada `CreditCardCalculator` (`agent/ui/credit-card-calculator-fixes` desde `e6f491f`):**
  - `CreditCardCalculator.isMonthPaid` (`lib/data/credit_card_calculator.dart`): eliminado el umbral `0.95` y el falso positivo con `monthlyPayment <= 0`; compara `paidAmount >= monthlyPayment` sin depender de `default_currency` ni fijar decimales arbitrarios.
  - `CreditCardCalculator.calculateMonthlyPayment`: evalúa la deuda al cierre del período consultado (`_calculateDebt(cardName, upTo: periodEnd)`), preservando consultas históricas tras liquidar la deuda en meses posteriores y manteniendo `0.0` cuando la deuda ya era `0` en ese período (`L2.4`).
  - Pruebas en `test/audit/t1_3b_credit_card_calculator_test.dart` (`9/9` pasan).
- **Tarea `L1.5 / T1.1` (Unificación de `AccountItem` en `agent/ui/t1-1-account-item-dedup` desde `9240b84`):**
  - Eliminadas las clases `AccountItem` duplicadas en `lib/Screens/add_expense.dart`, `lib/Screens/transfer.dart` y `lib/Screens/statistics.dart`; las 3 pantallas importan y re-exportan `lib/data/models/account_item.dart`.
  - `AccountItem` canónico incorpora `balanceAsDouble` (getter/setter sobre `balance` String) y `fromJson` tolerante a `balance` `String`/`num` e `icon`/`iconColor` `int`/`String`, preservando `id`, `includeInTotal`, `creditLimit`, `cutoffDay`, `paymentDay` e `interestRate` sin inventar defaults sobre opcionales nulos.
  - `transfer.dart` (`_saveAccountsToPrefs`) usa `item.toJson()` en lugar de construir un mapa parcial con `'includeInTotal': true`.
  - Pruebas en `test/audit/t1_1_account_item_test.dart` (`3/3` pasan).
- **Decisión mínima pendiente (moneda/precisión por cuenta):** la comparación directa de `CreditCardCalculator.isMonthPaid` no resuelve la dependencia de moneda global (`default_currency` en `SharedPreferences`) que todavía tiene `Responsibility.isAmountCovered`. Ni `AccountItem`, ni `Responsibility`, ni `Add_data` persisten `currencyCode` propio aún; la precisión monetaria por cuenta queda pendiente de autorización antes de añadir `currencyCode` o migrar modelos/datos.
- **Pendiente de aprobación humana:** Decisión de `currencyCode` persistido en `AccountItem` / precisión monetaria en `Responsibility.isAmountCovered`, y siguientes frentes (`T1.3c` UI restante / `T1.4` / Ola 2 IA). Decisions `D1`–`D7` (`D8` confirmada).
