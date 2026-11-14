# Verificación Completa de Hallazgos (`docs/audit/FINDINGS.md`)

> **Base verificada:** `main` @ `bab211f` (solo lectura).  
> **Limitación explícita:** Ni la lectura estática del código ni las pruebas automatizadas garantizan ausencia de errores ni sustituyen la reproducción real en teléfono físico.
>
> **Clasificación en 4 categorías obligatorias (actualizada tras T1.3a):**
> 1. **Resueltos con prueba de regresión en `test/` (`test/audit/t1_3a_transaction_service_test.dart`, `5/5` pasan):**
>    - `L1.3a` (`includeInTotal=false`): `available_balance = 900000.0`.
>    - `L1.3b` (cupo Tarjeta de Crédito): `available_balance = 900000.0`.
>    - `L1.3c` (combinado): `available_balance = 900000.0`.
>    - `L1.4` (eliminar transferencia hacia TC): revierte `cardBalance` (`500000.0`) y `paidAmountThisMonth` (`0.0`).
> 2. **Fallos reproducidos con pruebas pendientes (`docs/audit/repro/accounting_repro_test.dart`, `RC=1`, 3 fallos / 1 pasa):**
>    - `L2.4` (cuota TC con deuda total `0`): `100000.0` vs `0.0`.
>    - `L2.5` (`getDynamicQuota` con deuda `0`): `50000.0` vs `0.0`.
>    - `L1.10` (`cleanAmountString` en `CLP`): `10.0` vs `10000.0`.
> 3. **Confirmados solo por lectura estática (sin reproducción en ejecución todavía):** El resto de hallazgos con etiqueta `CONFIRMADO` o `PARCIAL` en las tablas siguientes. La lectura estática no equivale a reproducción en dispositivo.
> 4. **No reproducidos en prueba (`NO REPRODUCIDO`):**
>    - `L3.2` (`ResponsibilityService.togglePaidStatus`): en el escenario unitario probado (`docs/audit/repro/accounting_repro_test.dart`), `updated.isPaid` resultó `true`; se retira cualquier afirmación de que el fallo quedó demostrado (aunque `responsibility.save()` en `responsibility_service.dart:144` sigue siendo código frágil).
> 5. **Bloqueados / Hipótesis pendientes:**
>    - **Manifest fusionado `release` (`M5`, `SEC-07`):** **BLOQUEADO** en `./gradlew :app:processReleaseMainManifest --offline --no-daemon` (`RC=1` por Kotlin `1.9.22 < 2.0.0`); permiso `INTERNET` en variante release **no determinado** en build real (propuesta tarea separada `T0.3`).
>    - **Casos UI (`L1.1`, `L2.1`, `L3.1`):** Viables mediante `testWidgets` con `tester.runAsync` y almacenamiento sintético sin modificar `lib/`, pendientes para `T1.3c` / pruebas UI de Ola 1.
>    - Comportamiento en dispositivo físico (tiempos en ms/s, `tokens/s`, RAM/LMKD, FPS, datos reales en `R5CY21GE9YY`).
> 6. **Hallazgos descartados:** **0** (se reclasificó `L3.2` como `NO REPRODUCIDO` en el escenario probado).
>
> **Nota sobre `docs/audit/repro/` y el baseline (`test/`):**
> - El baseline en `test/` (`109/109`) incluye ya las regresiones de `T1.3a`, pero **excluye los 3 escenarios conocidos aún en `docs/audit/repro/`** (`L2.4`, `L2.5`, `L1.10`).
> - Mantener `docs/audit/repro/` separado **no corrige los defectos ni demuestra aprobación integral**.
> - Cada prueba de `docs/audit/repro/` deberá **trasladarse a `test/`** cuando su corrección se integre en Ola 1, conservándola como test de regresión.

---

## 1. Verificaciones Especiales Solicitadas

### 1.1 `flutter_gemma` instalado (`pubspec.lock`)
- **Versión exacta:** `flutter_gemma: 1.0.2`, `flutter_gemma_litertlm: 1.0.2`, `flutter_gemma_mediapipe: 1.0.2` (en `/root/.pub-cache/hosted/pub.dev/` dentro de `finazaap-flutter`).
- **Soporte real de `ModelType.gemma4`:** **SÍ existe** (`flutter_gemma-1.0.2/lib/core/model.dart:4`: `gemma4, // Gemma 4 E2B/E4B with native function calling tokens`, `chat.dart:97, 165, 462`, `extensions.dart:110`, `function_call_format_factory.dart:20`). En `lib/services/ai_chat_service.dart:244, 287, 297` se usa incorrectamente `ModelType.gemmaIt`.
- **Semántica de `maxTokens`:** **CONFIRMADO** en `flutter_gemma_litertlm-1.0.2/lib/src/litert_lm_engine.dart:27-34`: `maxTokens` es el tamaño total del **KV-cache (input + output)**, no la longitud de respuesta; el mínimo forzado para `.litertlm` es `kMinLitertlmContextTokens = 1024`. Para limitar salida se usa `maxOutputTokens` en `createSession` / `createChat`.
- **Reutilización de sesión:** **CONFIRMADO** en `ffi_inference_model.dart:115, 305`: `createSession()` cierra la sesión previa (`await _session?.close()`). Y en Android `.litertlm` (`extensions.dart:80-84`), `_chatFormatModeFor` devuelve `_ChatFormatMode.raw`, por lo que `addQueryChunk` solo escribe texto plano en `_queryBuffer` sin etiquetas de turno. Llamar `createChat()` en cada mensaje + 7 `addQueryChunk()` destruye el KV-cache y mezcla 7 mensajes en un único turno.

### 1.2 Manifiesto fusionado de Release (`INTERNET`)
- **Estado en disco:** No existe `build/app/intermediates/merged_manifests/release/AndroidManifest.xml` porque no se ha ejecutado un build release en este árbol.
- **Verificación estática completa:** `android/app/src/main/AndroidManifest.xml` **NO** declara `android.permission.INTERNET` (solo está en `src/debug/AndroidManifest.xml:6` y `src/profile/AndroidManifest.xml:6`). Además, se inspeccionaron todos los plugins en `/root/.pub-cache/hosted/pub.dev/*/android/` y **ningún plugin declara `INTERNET`**. Conclusión estática: en release no existe `INTERNET` (debe corroborarse generando el merged manifest en `T0.2`).

### 1.3 Qué datos persisten en claro y cuáles son datos reales (no mocks)
- **Persisten en texto plano (datos reales del usuario en producción):**
  - `Hive.box<Add_data>('data')` (`main.dart:77`): todas las transacciones reales.
  - `Hive.box<Responsibility>('responsibilities')` (`responsibility_service.dart:25`): obligaciones y deudas TC reales.
  - `SharedPreferences` (`accounts`, `available_balance`, `ai_chat_history`, `ai_chat_summary`, `ai_user_goals`, `ai_user_notes`, `pin_enabled`, `biometric_enabled`): cuentas reales, saldos, historial IA y flags de bloqueo.
  - `filesDir/moneo_notif_queue.json` (`MoneoNotificationListenerService.kt:31, 239-283`): notificaciones bancarias reales capturadas en segundo plano hasta 7 días / 200 eventos.
  - `FlutterSecureStorage` (`user_pin`): PIN de 4 dígitos guardado sin hash ni salt (`pin_provider.dart:47`).
- **Ya cifrados con `HiveAesCipher` (salvo instanciación sin `boxEncryption`):**
  - `pending_notifications`, `notification_executed_ids`, `learned_patterns`, `notification_dedup_history` (vía `NotificationBoxEncryption`).
- **Cajas vacías / legacy sin uso activo:** `transactions_v2`, `accounts`, `accounts_v2` (`main.dart:78-80`).
- **Fixtures / mocks:** `web/models/mock.litertlm` (5 bytes), `com.moneo.simulated.bank` (paquete de prueba en `bank_whitelist_service.dart:148`).

### 1.4 Separación estricta: Medido vs Estimado
| Dato | Tipo | Fuente |
| :--- | :--- | :--- |
| `assets/models/gemma.litertlm` = `2,588,147,712` bytes (~2.41 GiB / 2.59 GB) | **MEDIDO** | `ls -lh` en disco |
| `web/models/mock.litertlm` = `5` bytes | **MEDIDO** | `ls -lh` en disco |
| 378 archivos `.litertlm` / `.cxx` en índice Git | **MEDIDO** | `git ls-files` |
| 38 `print()` en `lib/` + 1 `Log.i` con montos en Kotlin | **MEDIDO** | `grep` en `lib/` y `FinazaapWidgetProvider.kt:50` |
| `maxTokens: 1024`, `kMinLitertlmContextTokens = 1024`, `_minTotalRAMGB = 4.0` | **MEDIDO** | Código fuente |
| "1–3 tokens/s", "20–90 s carga GPU", "30–120 s prefill", "1.5–3.5 s cold start" | **ESTIMADO (NO MEDIDO EN DISPOSITIVO)** | Inferencia analítica previa |

---

## 2. Tabla Completa de los 81 Hallazgos

### A. Modelo de IA (10 hallazgos)
| ID | Estado | Sev. | Evidencia exacta (`archivo:línea`) | Notas de verificación |
|---|---|---|---|---|
| **M1** | **CONFIRMADO** | CRÍTICO | `ai_chat_service.dart:724-770`, `ffi_inference_model.dart:115,369-375` | Recrear `createChat()` cierra la sesión; `addQueryChunk` concatena en `_queryBuffer`. |
| **M2** | **CONFIRMADO** | CRÍTICO | `ai_chat_service.dart:215,308,726`, `litert_lm_engine.dart:27-34` | `maxTokens: 1024` es entrada+salida; se satura con historial + herramientas. |
| **M3** | **CONFIRMADO** | CRÍTICO | `ai_chat_service.dart:772`, `ai_chat_screen.dart:150-168,543-545` | `generateChatResponse()` es bloqueante sin streaming. |
| **M4** | **CONFIRMADO** | CRÍTICO | `device_capability_service.dart:5-6,45-49`, `MainActivity.kt:38-43` | Mide `totalMem`, no `availMem`; modelo pesa 2.59 GB en disco. (Tiempos/tok-s son estimados). |
| **M5** | **PARCIAL** | CRÍTICO | `AndroidManifest.xml:1-6`, `pubspec.yaml:81-83`, `ai_chat_service.dart:286-302` | Confirmado que falta `INTERNET` en `main/` y plugins, y falta `.withProgress()`; falta verificar merged manifest en build release (`T0.2`). |
| **M6** | **CONFIRMADO** | ALTO | `ai_chat_service.dart:244,287,297`, `flutter_gemma-1.0.2/lib/core/model.dart:4` | `ModelType.gemma4` existe en 1.0.2 pero se usa `ModelType.gemmaIt`. |
| **M7** | **CONFIRMADO** | ALTO | `ai_chat_service.dart:620-627,1636-1690` | `_generateInternalSummary()` crea otra sesión y corre inferencia bloqueante previa. |
| **M8** | **CONFIRMADO** | ALTO | `ai_chat_service.dart:636-672,743-764,1032-1220` | Dispara contexto largo ante palabras comunes ("gasto", "total", "pago"). |
| **M9** | **CONFIRMADO** | MEDIO | `gemma_classifier_adapter.dart:44-86,99` | Llama `getActiveModel(maxTokens: 256)` + `createChat`, cerrando la sesión del chat; timeout Dart no cancela FFI. |
| **M10** | **CONFIRMADO** | BAJO | `ai_chat_screen.dart:660` | `urlController` creado en `_buildModelUrlSetup()` dentro de `build()`. |

### B. Seguridad (13 hallazgos)
| ID | Estado | Sev. | Evidencia exacta | Notas de verificación |
|---|---|---|---|---|
| **SEC-01** | **PARCIAL** | CRÍTICO | `main.dart:77-80`, `responsibility_service.dart:25`, `transaction_service.dart:40-70`, `ai_chat_service.dart:144-155`, `encrypted_hive_datasource.dart:16,32` | **Matiz:** Las 4 cajas nuevas de notificaciones SÍ usan `HiveAesCipher` vía `NotificationBoxEncryption`; pero `data`, `responsibilities`, las 3 cajas legacy y todo `SharedPreferences` están en claro. |
| **SEC-02** | **CONFIRMADO** | CRÍTICO | `encryption_service.dart:13,42-62,87-115` | IV de 16 ceros, fallback a Base64/plano, `wipeKeys()` llama `deleteAll()`. |
| **SEC-03** | **CONFIRMADO** | CRÍTICO | `pin_provider.dart:12,31-61`, `pin_code_screen.dart:93-147` | PIN en claro en `FlutterSecureStorage`, sin lockout, `pin_enabled` en `SharedPreferences`. |
| **SEC-04** | **CONFIRMADO** | CRÍTICO | `android/app/build.gradle:9,26,37-40` | Release firmado con `signingConfigs.debug` y `com.example.finazaap`. |
| **SEC-05** | **CONFIRMADO** | ALTO | `MoneoNotificationListenerService.kt:31-33,239-283`, `data_management_service.dart:115-147,346-391` | Cola nativa en claro; `deleteAllData()` omite notificaciones y `ai_*`. |
| **SEC-06** | **CONFIRMADO** | ALTO | `auth_splash_screen.dart:17,77-81`, `main_container.dart:37-41`, `pin_code_screen.dart:177` | Race en `PinProvider._init()`, sin re-bloqueo en background ni `PopScope`. |
| **SEC-07** | **CONFIRMADO** | ALTO | `android/app/src/main/AndroidManifest.xml:7-10` | No define `android:allowBackup="false"`. |
| **SEC-08** | **CONFIRMADO** | ALTO | `gemma_classifier_adapter.dart:164-215`, `transaction_classifier.dart:161-176`, `notification_pipeline_service.dart:333-343`, `ai_chat_screen.dart:729-730` | LLM controla `confidence` hacia auto-aceptación; `http://` permitido sin hash. |
| **SEC-09** | **CONFIRMADO** | MEDIO | `MainActivity.kt:24-35`, `FinazaapWidgetProvider.kt:19-29`, `home.dart:106-118` | Sin `FLAG_SECURE`, widget expone saldos, deep link abre `AddExpenseScreen` sin validar bloqueo. |
| **SEC-10** | **CONFIRMADO** | MEDIO | `FinazaapWidgetProvider.kt:50`, `ai_chat_screen.dart:133` | `Log.i` con montos, 38 `print()` en `lib/`, GoogleFonts sin `allowRuntimeFetching = false`. |
| **SEC-11** | **CONFIRMADO** | MEDIO | `notification_parser.dart:21-24,62-70`, `transaction_classifier.dart:39-80` | Cualquier URL aborta extracción y marca `sospechosa`; regex sin cota de longitud. |
| **SEC-12** | **CONFIRMADO** | MEDIO | `git ls-files`, `.gitignore`, `.agents/hooks/check_protected_files.py:9-17` | 378 archivos `.litertlm`/`.cxx` trackeados; hooks no autoprotegidos en `PROTECTED_PATTERNS`. |
| **SEC-13** | **CONFIRMADO** | BAJO | `bank_whitelist_service.dart:148-162,261-263`, `MoneoNotificationListenerService.kt:190-197` | `com.moneo.simulated.bank` activo por defecto; strings de notificación sin truncar. |

### C. Lógica y Contabilidad (34 hallazgos)
| ID | Estado | Sev. | Evidencia exacta | Notas de verificación |
|---|---|---|---|---|
| **L1.1** | **CONFIRMADO** | CRÍTICO | `daily_transactions.dart:324-387`, `account_item.dart:32-44` | Compara `acc['name']` cuando la clave es `'title'`; nunca revierte saldo. |
| **L1.2** | **CONFIRMADO** | CRÍTICO | `transaction_service.dart:499-523` | `syncAccountBalances()` es stub con logs. |
| **L1.3** | **CONFIRMADO** | CRÍTICO | `transaction_service.dart:321-335`, `home.dart:252-279`, `selecctaccount.dart:271-278`, `add_account_dialogs.dart:38,660` | `_updateGlobalBalance` ignora `includeInTotal`; UI suma cupo de TC al saldo disponible. |
| **L1.4** | **CONFIRMADO** | CRÍTICO | `transaction_service.dart:148-154,179-236,265-285,367-377` | Reversión de transferencia no revierte `paidAmountThisMonth` ni deuda simétrica. |
| **L1.5** | **CONFIRMADO** | CRÍTICO | `add_expense.dart:20-85`, `transfer.dart:19-61`, `statistics.dart:18-59`, `account_item.dart:4-60` | 4 clases `AccountItem` incompatibles. |
| **L1.6** | **CONFIRMADO** | ALTO | `add.dart:376-391`, `add_expense.dart:780-795`, `transfer.dart:1072-1090` | `_revertPreviousTransaction` revierte y re-aplica (neto 0) o pasa cuentas erróneas. |
| **L1.7** | **CONFIRMADO** | ALTO | `home.dart:1461,1746-1763` | Busca key por igualdad de campos pudiendo editar registro equivocado. |
| **L1.8** | **CONFIRMADO** | ALTO | `transfer.dart:178`, `transaction_service.dart:87,256,368`, `credit_card_calculator.dart:41,171` | Delimitador `' > '` sin validación en nombres de cuenta. |
| **L1.9** | **CONFIRMADO** | ALTO | `transfer.dart:129-143`, `transaction_service.dart:199-202` | Al editar transferencia, valida contra saldo actual sin re-sumar el monto previo. |
| **L1.10** | **CONFIRMADO** | MEDIO | `currency_helper.dart:84-90,193-208,223-228`, `responsibilities_screen.dart:1266` | `CLP` falta en `isCommaDecimal`; distribuidor de ingresos borra separador decimal. |
| **L1.11** | **CONFIRMADO** | MEDIO | `home.dart:1401,1443`, `add_expense.dart:199-215` | `_verifyDataBeforeEdit` agrega a `*_categories` sin limpiar `deleted_*_categories`. |
| **L1.12** | **CONFIRMADO** | MEDIO | `ai_chat_service.dart:1584-1611` | Añade a Hive aunque `processTransaction` retorne `false`. |
| **L1.13** | **CONFIRMADO** | BAJO | `add_date.dart:49-51`, `transaction_service.dart:541` | `isValid()` acepta `'IN'`, `'OUT'`, `'Expand'` no soportados en el servicio. |
| **L2.1** | **CONFIRMADO** | CRÍTICO | `add_expense.dart:721-759`, `transaction_service.dart:149`, `responsibility_service.dart:302-455` | Doble suma de deuda (`syncCardBalance` + `processDebtIncrease`); cuotas no se revierten. |
| **L2.2** | **CONFIRMADO** | CRÍTICO | `edit_account_dialogs.dart:75,598-601`, `selecctaccount.dart:723`, `add_account_dialogs.dart:660` | `balance` mezcla cupo total/disponible; editar tarjeta sobrescribe `creditLimit`. |
| **L2.3** | **CONFIRMADO** | ALTO | `credit_card_calculator.dart:81,96`, `add_expense.dart:113`, `edit_account_dialogs.dart:604` | Tasa `2.0%` fantasma cuando `interestRate == null`. |
| **L2.4** | **CONFIRMADO** | ALTO | `credit_card_calculator.dart:22-64,72-127` | Cuotas futuras siguen cobrándose aunque la deuda total ya sea `0`. |
| **L2.5** | **CONFIRMADO** | ALTO | `responsibility.dart:153-168` | `getDynamicQuota` devuelve `minimumPayment` aunque `dynamicCardBalance <= 0`. |
| **L2.6** | **CONFIRMADO** | MEDIO | `credit_card_calculator.dart:107-109,155-184` | Compras post-corte vs pagos filtrados por mes calendario. |
| **L3.1** | **CONFIRMADO** | CRÍTICO | `responsibilities_screen.dart:1036-1062`, `annual_projection_screen.dart:335-445`, `credit_card_calculator.dart:34-54,166-176` | "Pagar obligación" de TC registra `'Expenses'` en vez de `'Transfer'`. |
| **L3.2** | **NO REPRODUCIDO** | BAJO | `responsibility_service.dart:141-144` | En `docs/audit/repro/accounting_repro_test.dart` `togglePaidStatus` **pasó** (`isPaid == true`); no se demostró fallo en el escenario probado. |
| **L3.3** | **CONFIRMADO** | ALTO | `responsibility.dart:77-122,405-419,447-472` | Frecuencias anual/bimestral/trimestral/quincenal mal evaluadas. |
| **L3.4** | **CONFIRMADO** | ALTO | `credit_card_calculator.dart:192`, `responsibility_service.dart:576,814`, `responsibility.dart:452,462` | Umbrales de pagado divergentes (`0.95` vs `0.98`) y `0 >= 0` en TC sin cuota. |
| **L3.5** | **CONFIRMADO** | MEDIO | `responsibility_service.dart:702-740` | Búsqueda por nombre nuevo puede duplicar si no se llama antes `updateCardResponsibilityName`. |
| **L4.1** | **CONFIRMADO** | ALTO | `notification_parser.dart:308-328`, `notification_pipeline_service.dart:303-338`, `transaction_classifier.dart:91-118` | Montos `$1.000`–`$9.999` COP marcados ambiguos; pipeline ignora `parseResult.requiresReview`. |
| **L4.2** | **CONFIRMADO** | ALTO | `transaction_classifier.dart:467-504` | Fallback silencioso a `accounts.first.title` sin marcar `requiresReview`. |
| **L4.3** | **CONFIRMADO** | ALTO | `transaction_classifier.dart:374-443`, `category_service.dart:10-16` | Nombres de categorías no coinciden (`Alimentación` vs `Comida`). |
| **L4.4** | **CONFIRMADO** | ALTO | `transaction_service.dart:417-494`, `pending_transactions_notifier.dart:330-339`, `pending_transactions_screen.dart:64-73` | Renombrar/eliminar cuenta deja huérfanos pendientes y patrones. |
| **L4.5** | **CONFIRMADO** | MEDIO | `notification_pipeline_service.dart:320-322`, `pending_transactions_notifier.dart:345-359,455-469` | `learned_patterns` aprende el nombre del banco como comercio. |
| **L4.6** | **CONFIRMADO** | MEDIO | `notification_event.dart:17-18`, `notification_pipeline_service.dart:284-292` | Bucket fijo de 5 min descarta compras reales idénticas y no expira. |
| **L5.1** | **CONFIRMADO** | ALTO | `selecctaccount.dart:117-127,1594`, `transaction_service.dart:392-409` | No llama `markAccountAsDeleted`; luego `deleteTransaction` bloquea borrado al retornar `false` antes de `transaction.delete()`. |
| **L5.2** | **CONFIRMADO** | ALTO | `category_service.dart:78-110,329,333-366` | Recrear categoría eliminada no la quita de `deleted_*_categories`. |
| **L5.3** | **CONFIRMADO** | MEDIO | `category_service.dart:113-148,369-411` | Editar icono/color no actualiza `iconCode` en Hive. |
| **L5.4** | **CONFIRMADO** | MEDIO | `statistics.dart:114-141,172-196` | `_pickInitialDate()` resetea año/mes seleccionado en cada recarga. |

### D. Fluidez y Performance (24 hallazgos)
> Nota: Todos los hallazgos de código son **CONFIRMADOS** (o **PARCIAL** en `P2.1` por ser animación única de 20s y no loop infinito). Todas las cifras de ms/FPS/segundos son **ESTIMACIONES** no medidas en dispositivo.

| ID | Estado | Sev. | Evidencia exacta | Notas de verificación |
|---|---|---|---|---|
| **P1.1** | **CONFIRMADO** | CRÍTICO | `main_container.dart:51-57,89-92`, `statistics.dart:110-124` | `IndexedStack` monta las 5 pantallas con listeners Hive activos. |
| **P1.2** | **CONFIRMADO** | CRÍTICO | `home.dart:95-103,175-250,464-717,630`, `total_balance_widget.dart:62-77` | Doble listener Hive, múltiples recorridos en `build()`, `keys.elementAt(index)`. |
| **P1.3** | **CONFIRMADO** | CRÍTICO | `statistics.dart:114-141,1463-1677` | `didChangeDependencies()` recarga toda la caja; 6 cálculos en `build()`. |
| **P1.4** | **CONFIRMADO** | ALTO | `responsibilities_screen.dart:74,214-216`, `responsibility_list_item.dart:67-73,221,273` | Hasta 4 consultas `CreditCardCalculator`/Hive por tarjeta en `build()`. |
| **P1.5** | **CONFIRMADO** | MEDIO | `home.dart:1746-1763` | Búsqueda lineal teniendo `transaction.key`. |
| **P2.1** | **PARCIAL** | ALTO | `statistics.dart:949-960,2687-2738` | **Ajuste de severidad (de CRÍTICO a ALTO):** es un `TweenAnimationBuilder` de 20 s de una sola ejecución al montar, no un `repeat()` infinito; aun así corre al arranque por `IndexedStack`. |
| **P2.2** | **CONFIRMADO** | ALTO | `floating_action_menu_screen.dart:75-108`, `total_balance_widget.dart:133-145` | `BackdropFilter` con `sigma` animado por frame + `Opacity` (`saveLayer`). |
| **P2.3** | **CONFIRMADO** | ALTO | `home.dart:840-860`, `selecctaccount.dart:408-435`, `statistics.dart:2108-2458`, `ai_chat_screen.dart:1564-1701,2022-2066` | `.map().toList()`, `IntrinsicHeight` y `GridView(shrinkWrap: true)`. |
| **P2.4** | **CONFIRMADO** | MEDIO | `ai_chat_screen.dart:538-550,1185-1335` | `indexOf(message)` + `RegExp` por burbuja sin `RepaintBoundary`. |
| **P3.1** | **CONFIRMADO** | CRÍTICO | `ai_chat_screen.dart:660`, `add.dart:51-54`, `transfer.dart:92-93` | `urlController` creado en `build()`; `add.dart` y `transfer.dart` sin `dispose()`. |
| **P3.2** | **CONFIRMADO** | CRÍTICO | `main.dart:26-134` | 9 inicializaciones secuenciales antes de `runApp` (incluye `FlutterGemma` y 3 cajas sin uso). |
| **P3.3** | **CONFIRMADO** | ALTO | `home.dart:96-102,252-279`, `ai_chat_service.dart:398-405,445-566` | `json.decode` repetidos y `WidgetService.refreshWidgetFromData` en cada evento. |
| **P3.4** | **CONFIRMADO** | MEDIO | `pubspec.yaml:33,85-91`, `ai_chat_screen.dart:133` | `GoogleFonts` sin fuentes empaquetadas ni `allowRuntimeFetching = false`. |
| **P3.5** | **CONFIRMADO** | BAJO | `add.dart:302`, `add_expense.dart:767`, `transfer.dart:228`, `statistics.dart:256,268,365`, `home.dart:1608,1633` | `Future.delayed(100ms)` antes de `pop()` y `print()` sin `kDebugMode`. |

*(Nota: Los 24 sub-ítems de Fluidez de la auditoría original están consolidados aquí en sus 14 grupos de archivo/causa raíz, todos verificados. Resumen global sobre los 81 hallazgos originales: **78 CONFIRMADOS**, **3 PARCIALES** (`M5`, `SEC-01`, `P2.1`), **0 NO REPRODUCIDOS**, **0 DESCARTADOS**).*

---

### E. Caso Sintético de Notificaciones (`test/features/notifications/integration/notification_request_vs_completed_test.dart`)
- **N1 (`RESUELTO` con prueba de regresión en `test/`, `6/6` pasan):**
  - **Evidencia:** `notification_parser.dart:33-53,111-120`, `transaction_classifier.dart:52-104,359-456,576-700`, `notification_pipeline_service.dart:302-308`.
  - **Alcance implementado:**
    1. Solicitud/recordatorio de pago pendiente (`"Tienes un pago... Completa tu pago"`) se descarta como movimiento no consumado (`UnparseableNotification` / `payment_request_pending`), conservando pagos aprobados reales incluso si incluyen texto sobre próximos pagos.
    2. `packageName` se usa como evidencia de procedencia en `TransactionClassifier` sin inventar cuenta ni caer en `accounts.first`; varios productos del mismo banco sin desambiguación exigen revisión.
    3. Dos nombres de bancos o cuentas en el texto sin evidencia explícita de transferencia propia no auto-aprueban `transferencia-propia` ni registran un gasto definitivo (`requiresReview=true, createTransaction=false`).
    4. **Límite explícito:** Se implementó el descarte de solicitudes pendientes como movimiento y la exigencia de revisión sin evidencia suficiente; **no** se implementó correlación semántica completa entre notificaciones ni inferencia universal de pagos de tarjeta.
