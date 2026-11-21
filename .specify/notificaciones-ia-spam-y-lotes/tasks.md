# Tareas de Implementación — `notificaciones-ia-spam-y-lotes`

> **Orden estricto por cortes verificables.** Cada corte incluye sus pruebas unitarias/widget y análisis estático en Docker.

- [x] **T1 — Captura nativa completa y Whitelist (`com.grability.rappi` + Nequi):**
  - [x] Actualizar `MoneoNotificationListenerService.kt` (comparación case-insensitive, `EXTRA_TEXT_LINES` / `EXTRA_SUB_TEXT` / `EXTRA_SUMMARY_TEXT` / `EXTRA_INFO_TEXT` / `EXTRA_MESSAGES` / `tickerText`, `channelId`, `category`, `isOngoing`, `isGroupSummary` con contenido).
  - [x] Actualizar `AndroidNotificationSource`, `NotificationEvent` y `BankWhitelistService` (`com.grability.rappi`, case-insensitive).

- [x] **T2 — Parser numérico exacto, léxico Nequi y señales de promos:**
  - [x] Corregir regex de montos y validación de separadores en `NotificationParser` (`$5800`, `$5.800`, `$5.800.00`, `$5,800.00`, `candidateAmounts`).
  - [x] Agregar léxico real Nequi/Colombia, filtro `isOngoing` y detección `isPromoSignal`.
  - [x] Añadir/actualizar pruebas unitarias en `test/features/notifications/services/notification_parser_test.dart`.

- [x] **T3 — Memoria de Spam (`dismissed_patterns`) y cuarentena de 5 días (`notification_spam_items`):**
  - [x] Crear `lib/features/notifications/domain/models/spam_models.dart` y `lib/features/notifications/services/spam_patterns_service.dart`.
  - [x] Integrar `spamItems`, auto-poda `> 5 días`, `discardItem` → aprendizaje + Spam, `confirmSpamItem` y `restoreFromSpam` en `PendingTransactionsNotifier`.
  - [x] Conectar `packageName` y `alias` en `recordConfirmation`/`recordCorrection` evitando nombres genéricos de banco como `merchantKey`.
  - [x] Escribir pruebas unitarias de spam y retención 5 días.

- [x] **T4 — Coordinador Único de Gemma Local (`LocalGemmaCoordinator`) + Cerebro IA Context-Aware:**
  - [x] Crear `lib/features/notifications/services/local_gemma_coordinator.dart` (singleton mutex, chequeo RAM `DeviceCapabilityService`, `maxTokens: 1024`, liberación tras lote y ante `didHaveMemoryPressure`).
  - [x] Conectar `AiChatService`, `DefaultGemmaInferenceClient` y `main.dart` al coordinador.
  - [x] Actualizar `GemmaClassifierAdapter` con `NotificationAiContext`, presupuesto fijo de tokens (`<= 550` en local), JSON completo (`is_transaction`, `description`, `account_name`, `destination_account`, `category`, `amount`) y timeout local `18s`.
  - [x] Refactorizar `TransactionClassifier`: atajo 0-IA para Spam consolidado, IA Context-Aware con validación cruzada Post-IA (monto + catálogo real de cuentas y `CategoryService`), y fallback determinista mejorado (`com.grability.rappi`, `RappiCard` vs `Rappi`, transferencias).

- [x] **T5 — Ventana cruzada adaptativa de 5 minutos y diagnóstico en `NotificationPipelineService`:**
  - [x] Implementar buffer de lote de 5 min con `flushBatchNow()`, contexto deslizante de 10 min, enrutamiento a `Spam` (`!isTransaction`) vs `Pendientes`, liberación de Gemma tras lote y registro local de diagnóstico (últimos 25 eventos de apps permitidas).
  - [x] Escribir pruebas unitarias de lotes cruzados, presupuesto de tokens, guardrails post-IA y ciclo de vida de RAM.

- [x] **T6 — UI de Bandeja (`Pendientes | Spam`), `CorrectionDialog` sin NU por defecto y Diagnóstico en Ajustes:**
  - [x] Actualizar `PendingTransactionsScreen` con vista `Spam (M)` accesible desde cabecera (`0 px` robados al viewport), banner de 5 días y tarjetas de Spam (`Confirmar spam`, `A Pendientes`, `Corregir`).
  - [x] Corregir `CorrectionDialog` (sin preseleccionar NU cuando `accountName == null`, match flexible de categorías de `CategoryService`).
  - [x] Añadir visor de diagnóstico de notificaciones en `SettingsScreen`.
  - [x] Actualizar y ampliar widget tests (`pending_spam_tab_test.dart`, `correction_dialog_categories_test.dart`).

- [x] **T7 — Verificación integral en Docker:**
  - [x] Ejecutar `dart analyze` (`No issues found!`) y `flutter test --no-pub -j 1` (`170/170` pasaron en Docker `finazaap-flutter`).
  - [x] Actualizar `docs/handoff/CURRENT_STATE.md` y `docs/handoff/ACTIVE_TASK.md`.
  - [ ] Consolidar en `integration/notificaciones-rag-y-multi-ia` (previa aprobación de `git merge`) y recompilar APK para validación humana en dispositivo.
