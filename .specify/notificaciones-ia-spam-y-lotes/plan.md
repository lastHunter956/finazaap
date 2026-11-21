# Plan Arquitectónico — `notificaciones-ia-spam-y-lotes`

> **Spec de referencia:** `.specify/notificaciones-ia-spam-y-lotes/spec.md`

---

## 1. Mapa de Componentes y Cambios

### Capa Nativa Android (sin tocar `AndroidManifest.xml` ni `build.gradle`)
- `android/app/src/main/kotlin/com/example/finazaap/MoneoNotificationListenerService.kt`
  - Comparación *case-insensitive* de `allowedPackages`.
  - Extracción enriquecida de `title` (`EXTRA_TITLE`, `EXTRA_TITLE_BIG`), `body` (`EXTRA_BIG_TEXT`, `EXTRA_TEXT`, `EXTRA_TEXT_LINES`, `EXTRA_SUB_TEXT`, `EXTRA_SUMMARY_TEXT`, `EXTRA_INFO_TEXT`, `EXTRA_MESSAGES`, `tickerText`), `channelId` (API 26+), `category`, `isOngoing`, `isGroupSummary`.
  - Política de `FLAG_GROUP_SUMMARY`: ignorar solo si el texto extraído está vacío o es un contador genérico (`"N mensajes"`, `"N notificaciones"`).
  - Buffer circular nativo en RAM de los últimos 25 eventos de apps permitidas para diagnóstico (sin tocar apps no permitidas).

### Modelos de Dominio (`lib/features/notifications/domain/models/`)
- `notification_event.dart`: añadir campos opcionales retrocompatibles (`channelId`, `category`, `subText`, `summaryText`, `tickerText`, `textLines`, `isOngoing`, `isGroupSummary`).
- `notification_parse_result.dart`: añadir `candidateAmounts` (`List<double>`) e indicador `isPromoSignal` (`bool`) en `ParsedTransaction`.
- `transaction_classification.dart`: añadir `isTransaction` (`bool`, default `true`), `spamReason` (`String?`), `suggestedDescription` (`String?`), `suggestedAmount` (`double?`) y `aiAnalyzed` (`bool`).
- `spam_models.dart` *(nuevo archivo cohesivo)*: `DismissedPattern` (firma de spam aprendida con `packageName`, `channelId`, `templateText`, `confirmations`, `rescuedCount`, `status`) y `SpamNotificationItem` (ítem en cuarentena de **5 días**, con `detectedAt`, `expiresAt`, `spamReason`, `spamSource`, `matchedRuleKey`, y el `PendingTransactionItem` subyacente).

### Servicios Core (`lib/features/notifications/services/`)
- `bank_whitelist_service.dart`: agregar `com.grability.rappi`, comparación *case-insensitive* en `isWhitelisted` / `getBankName`.
- `notification_parser.dart`:
  - Corregir regex de montos (fronteras numéricas estrictas, `\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?(?![\d.,])` antes de `\d+(?:[.,]\d{1,2})?(?![\d.,])`), COP 4 dígitos (`$5.800`), doble separador (`$5.800.00`, `$5,800,00`), extracción de `candidateAmounts`.
  - Añadir léxico Nequi/Colombia (`te envió`, `te llegó plata`, `pasaste`, `sacaste`, `recargaste`).
  - Detectar `isOngoing` → `UnparseableNotification` y señales de promo/marketing (`isPromoSignal`).
- `spam_patterns_service.dart` *(nuevo)*:
  - Gestiona `dismissed_patterns` (cifrada en Hive) con índice rápido en RAM (`CompactSimilarityIndex`) para matching `< 1 ms` por `(packageName, channelId)` y plantilla normalizada sin montos/números.
  - Métodos: `matchSpam(...)`, `recordUserDismissal(...)`, `reinforceSpam(...)`, `rescueFromSpam(...)` (degrada/desactiva regla), `getTopSpamExamplesForPrompt(...)`, `clearAll()`.
- `local_gemma_coordinator.dart` *(nuevo)*:
  - Singleton que gestiona una sola instancia de `InferenceModel` compartida con exclusión mutua (*mutex*) entre `AiChatService` y `DefaultGemmaInferenceClient`.
  - Verifica RAM libre con `DeviceCapabilityService.check()` (`!lowMemory && availRAMGB >= 1.8`) antes de cargar.
  - Soporta descarga inmediata tras lote (`releaseAfterBatch()`) y hook de `WidgetsBindingObserver` para `didHaveMemoryPressure` / pausa de app.
- `gemma_classifier_adapter.dart`:
  - Recibe `NotificationAiContext` (texto íntegro, `packageName`, `appName`, `channelId`, `candidateAmounts`, `last4`, `crossEvents` de la ventana de 5 min, `positiveExamples`, `spamExamples`, `userAccounts`, `userCategories`).
  - Construye prompt con presupuesto estricto de tokens (`AiFinancialTools.fitToTokenBudget`, `<= 550` tokens entrada para Gemma 2B, `maxTokens: 1024`, `timeout: 18s` local / `6s` cloud).
  - Parsea respuesta extendida (`is_transaction`, `spam_reason`, `classification`, `amount`, `merchant`, `description`, `category`, `account_name`, `destination_account`, `confidence`, `strategic_note`).
  - Delega carga/descarga de Gemma local a `LocalGemmaCoordinator`.
- `transaction_classifier.dart`:
  - Carga categorías reales desde `CategoryService` (con caché corto e inyectable en tests) y empareja con normalización + sinónimos.
  - Orden real de decisión:
    - **Etapa 0:** Anti-fraude (links/urgencia) → `sospechosa`; y verificación de `SpamPatternsService` → si hay spam consolidado/marcado, retorna `isTransaction: false` **sin llamar a la IA**.
    - **Etapa 1:** Patrón consolidado en `learned_patterns` (solo si comercio no es genérico de banco, `confirmations >= 4` o match exacto compatible con `packageName`, y sin eventos cruzados pendientes en la ventana de 5 min).
    - **Etapa 2 (IA Context-Aware cuando hay API Cloud o Gemma local disponible):** envía sobre tipado completo + contexto cruzado + Mini-RAG positivo/negativo + cuentas + categorías; aplica **validación cruzada Post-IA** (guardia de monto + guardia de catálogo real de cuentas/categorías).
    - **Etapa 3 (Fallback determinista mejorado):** cuando no hay IA / sin red / poca RAM / fallo. Reconoce `com.grability.rappi`, distingue `RappiCard` vs `Rappi`, mejora detección de transferencias y asigna categoría real de `CategoryService`.
- `notification_pipeline_service.dart`:
  - Incorpora `SpamPatternsService` + cola de **ventana cruzada adaptativa de 5 minutos** (`batchWindow = Duration(minutes: 5)`, tope `6` eventos, `flushBatchNow()` al reanudar o abrir Pendientes, contexto deslizante de 10 min).
  - Enruta resultados con `isTransaction == false` (por spam aprendido, promo o IA) hacia `PendingTransactionsNotifier.addSpamItem(...)` (retención máx. 5 días).
  - Registra traza local efímera de diagnóstico (últimos 25 eventos de apps permitidas).
  - Libera Gemma local (`LocalGemmaCoordinator.releaseAfterBatch()`) al finalizar cada lote.

### Estado y UI (`lib/features/notifications/presentation/` y `lib/Screens/`)
- `pending_transactions_notifier.dart`:
  - Administra también `spamItems` persistidos en caja Hive cifrada `notification_spam_items` con auto-poda estricta `> 5 días`.
  - `discardItem(id)`: aprende firma en `SpamPatternsService` y mueve el ítem a `spamItems` (en vez de perderlo sin aprender).
  - `confirmSpamItem(id)`: refuerza patrón en `SpamPatternsService` (`confirmations++`, `consolidado`) y elimina el ítem de `spamItems`.
  - `restoreFromSpam(id)`: degrada/desactiva la regla en `SpamPatternsService` y mueve el ítem a `pending_notifications` (para revisión o corrección inmediata).
  - Pasa `packageName` y `alias` a `LearnedPatternsService.recordConfirmation` / `recordCorrection`, filtrando nombres genéricos de banco como `merchantKey`.
- `pending_transactions_screen.dart` + `pending_transaction_card.dart`:
  - Añade `MoneoSegmentedControl` con pestañas **`Pendientes (N)`** y **`Spam (M)`**.
  - En pestaña **Spam**: muestra banner informativo (*"Se eliminan automáticamente tras 5 días"*) y tarjetas con motivo, días restantes y botones **Confirmar spam**, **No es spam → Pendientes** y **Corregir**.
- `correction_dialog.dart`:
  - Si `item.accountName == null`, deja `_selectedAccount = null` (placeholder `"Selecciona una cuenta"`, validación obligatoria) en lugar de forzar `_accounts.first` (NU).
  - Empareja `item.category` de forma insensible a tildes/mayúsculas contra las categorías reales cargadas de `CategoryService`.
- `settings_screen.dart`:
  - Añade sección/hoja discreta de **Diagnóstico de notificaciones** (últimos 25 eventos de apps permitidas con app, canal y resultado del filtro + botón limpiar) para diagnosticar Nequi/Rappi en vivo.
- `ai_chat_service.dart` + `main.dart`:
  - Conecta `AiChatService` a `LocalGemmaCoordinator` y añade `WidgetsBindingObserver` para liberar Gemma en `didHaveMemoryPressure` / pausa.

---

## 2. Estrategia de Pruebas (TDD + Verificación en Docker)

1. **Unit tests de Parser (`notification_parser_test.dart`):**
   - Montos críticos: `$5800`, `5800`, `$5.800`, `$5.800,00`, `$5,800.00`, `$5.800.00`, `$50000`, `$125000.00`, `$12,50`.
   - Nequi real: `"¡Te llegó plata! Juan te envió $ 50.000"`, `"Enviaste $ 25.000"`, `"Sacaste $ 100.000"`.
   - Rappi promos vs RappiCard real: `"¡Tienes $15.000 de descuento en tu compra!"` (`isPromoSignal: true`), `"Compra aprobada por $38.000 en El Corral con tu RappiCard"` (`isPromoSignal: false`).
   - `isOngoing: true` → `UnparseableNotification`.
2. **Unit tests de Spam & Retención 5 días (`spam_patterns_and_quarantine_test.dart`):**
   - Descartar aprende patrón y mueve a Spam; nueva promo similar de la misma app/canal va directo a Spam **con 0 llamadas a la IA**.
   - Reconfirmar Spam refuerza regla y borra tarjeta.
   - "No es spam" / Rescatar degrada la regla y devuelve a Pendientes.
   - Auto-poda elimina ítems de Spam con `> 5 días` y conserva los de `<= 5 días`.
3. **Unit tests de IA Context-Aware, Lote de 5 min y Validación Post-IA (`notification_ai_batch_and_guardrails_test.dart`):**
   - Presupuesto de tokens `<= 550` incluso con 200 patrones guardados (Mini-RAG).
   - Validación cruzada de monto (bloquea alucinación de monto por IA) y catálogo real de cuentas/categorías.
   - Ventana cruzada de 5 min: Nu débito + Nequi crédito → contexto cruzado para transferencia propia; Rappi pedido + RappiCard cobro → contexto cruzado.
   - `flushBatchNow()` procesa de inmediato.
   - `LocalGemmaCoordinator`: mutex sin doble carga, bloqueo por `lowMemory`/`availRAMGB < 1.8`, liberación tras lote.
4. **Widget tests (`pending_transactions_screen_test.dart` y `correction_dialog_test.dart`):**
   - Pestañas `Pendientes` y `Spam` con flujos Confirmar Spam / No es spam / Corregir.
   - `CorrectionDialog` NO preselecciona NU cuando `accountName == null`, exige elegir cuenta y preselecciona categoría por match insensible a tildes.
5. **Validación final en Docker:** `dart analyze` (`0` issues) + `flutter test --no-pub -j 1` completo.
