# Especificación — Notificaciones Inteligentes con IA Context-Aware, Spam (5 días), Lotes de 5 min y Optimización Gemma 2B

> **Módulo:** `notificaciones-ia-spam-y-lotes`
> **Base:** `007e52d` (`integration/notificaciones-rag-y-multi-ia`)
> **Rama de trabajo:** `agent/claude/notificaciones-ia-y-spam`
> **Rama de integración destino:** `integration/notificaciones-rag-y-multi-ia`

---

## 1. Objetivo y Problemas Resueltos

Convertir el módulo de notificaciones bancarias en la propuesta de valor fiable de Moneo (`finazaap`), resolviendo 9 fallos raíz verificados en producción:

1. **Bug de montos/decimales (`5800` → `580` / `58,00`):** El regex de `NotificationParser` truncaba montos de 4+ dígitos sin separador (`\d{1,3}` eager) y fallaba con `$5.800` (1 dígito entero en COP) y formatos doble separador (`$5.800.00`).
2. **IA secuestrada por reglas regex:** `TransactionClassifier` devolvía `confidence >= 0.85` en Etapa 2 incluso con categoría `'Otros'` o cuenta ambigua, impidiendo que las APIs configuradas o Gemma local procesaran la notificación; y cuando la IA se llamaba, recibía texto truncado (`merchant ?? rawText`) sin cuentas, categorías ni `packageName`.
3. **Apps híbridas (Rappi `com.grability.rappi` = comida + RappiPay/RappiCard):** Las promociones con dinero entraban como gastos reales, y `com.grability.rappi` no distinguía `Rappi` (débito/billetera) vs `RappiCard` (tarjeta de crédito).
4. **Nequi (`com.nequi.MobileApp`) sin captura:** `MoneoNotificationListenerService.kt` comparaba paquetes *case-sensitive*, descartaba cualquier `FLAG_GROUP_SUMMARY` aunque trajera contenido útil, e ignoraba `EXTRA_TEXT_LINES`, `EXTRA_SUB_TEXT`, `EXTRA_SUMMARY_TEXT`, `EXTRA_MESSAGES` y `tickerText`. Además `NotificationParser` no reconocía verbos reales de Nequi (`"te envió"`, `"te llegó plata"`, `"sacaste"`, `"pasaste"`).
5. **Descartar no aprendía:** `discardItem` borraba la tarjeta sin registrar firma de spam ni alimentar ejemplos negativos a la IA.
6. **Cuenta NU forzada por defecto:** Cuando `accountName` venía nulo, `CorrectionDialog` elegía silenciosamente `_accounts.first` (NU).
7. **Categoría casi siempre en blanco:** El clasificador usaba categorías hardcodeadas en vez de `CategoryService`, y `CorrectionDialog` exigía match exacto.
8. **Descripciones genéricas y contaminación de patrones:** Al fallar `_extractMerchant`, se guardaba el nombre del banco (`"Nu Colombia"`, `"Rappi"`) como `merchantKey` en `learned_patterns`; además `PendingTransactionsNotifier` no enviaba `packageName` ni `alias` al guardar patrones.
9. **Riesgo de OOM en Gemma 4 E2B local:** `DefaultGemmaInferenceClient` abría una segunda instancia independiente de `FlutterGemma.getActiveModel(maxTokens: 256)` sin compartirla con `AiChatService`, sin verificar RAM libre, sin descargarla tras usarla (`close()` nunca se llamaba) y con un timeout de `3s` irreal para arranque en frío.

---

## 2. Requisitos Funcionales

### RF-1: Captura Nativa Completa y Diagnóstico Local
- `MoneoNotificationListenerService.kt` captura de cada notificación permitida (comparación de `packageName` *case-insensitive*): `title`, `bigText`, `text`, `subText`, `summaryText`, `infoText`, `textLines[]`, `tickerText`, `channelId` (API 26+), `category`, `isOngoing`, `isGroupSummary`, `postTime`.
- No descarta `FLAG_GROUP_SUMMARY` si contiene texto/líneas reales distintas de un resumen genérico vacío (`"N mensajes nuevos"`).
- Mantiene en memoria/almacenamiento local efímero un **registro de diagnóstico** de los últimos 25 avisos de **apps permitidas únicamente** (respetando privacidad: nunca registra apps no seleccionadas), indicando `packageName`, `channelId`, estado del embudo y motivo, visible y borrable en Ajustes de Notificaciones.
- `BankWhitelistService` incluye `com.grability.rappi` (`Rappi / RappiPay / RappiCard`) junto a `com.rappipay.app` y compara paquetes *case-insensitive*.

### RF-2: Pre-filtros Deterministas y Parser Numérico Exacto
- Descarta eventos `isOngoing == true`, OTPs y recordatorios de pago pendientes.
- Mantiene anti-fraude en Etapa 0 (links/urgencia → `sospechosa`, `createTransaction: false`).
- **Parser numérico exacto:** parsea sin truncamiento ni errores de escala `$5800`, `5800`, `$5.800`, `$5.800,00`, `$5,800.00`, `$5.800.00`, `$50000`, `$1.250.000`, `$12,50`, `$12.50` y retorna lista de `candidateAmounts` para validación cruzada post-IA.
- **Léxico colombiano / Nequi:** reconoce `"te envió"`, `"te envio"`, `"te llegó plata"`, `"te llego plata"`, `"pasaste"`, `"sacaste"`, `"recargaste"`.
- **Detección preliminar de promos/marketing:** detecta señales claras de promoción (`descuento`, `cupón`, `cashback`, `gana hasta`, `ahorra`, `envío gratis`, `2x1`, `promo`, `oferta`, `pide ya`, `te regalamos`, `bono`) cuando no hay verbo explícito de transacción ejecutada.

### RF-3: Memoria de Spam (`dismissed_patterns`) y Pestaña **Spam** (máx. 5 días)
- Nueva caja Hive cifrada `dismissed_patterns` que almacena firmas normalizadas de spam: `packageName`, `channelId`, plantilla textual sin montos/números, tokens, `confirmations`, `rescuedCount`, `status` (`activo` | `consolidado` | `desactivado`).
- Nueva caja Hive cifrada `notification_spam_items` para la bandeja de Spam, aislada de `pending_notifications` y `'data'` (nunca altera saldos ni entra en *"Aceptar todo"*).
- **Retención máxima de 5 días:** todo ítem con `age > Duration(days: 5)` se purga y compacta automáticamente.
- **Atajo cero-IA para Spam marcado:** si una notificación entrante coincide con un patrón activo en `dismissed_patterns` (por `(packageName, channelId)` marcado o similitud textual `>= 0.85` en el mismo paquete), **NO se invoca a la IA** y se envía directamente a la pestaña **Spam**.
- **UI en `PendingTransactionsScreen`:** selector segmentado `Pendientes (N) | Spam (M)` usando `MoneoSegmentedControl`.
  - Desde **Pendientes**, pulsar **Descartar / Spam** registra/refuerza la firma en `dismissed_patterns` y mueve el ítem a la pestaña **Spam** (con retención 5 días).
  - Desde **Spam**, cada tarjeta muestra el motivo y los días restantes antes de auto-borrarse, con 2 acciones:
    1. **Confirmar spam:** refuerza `dismissed_patterns` (`confirmations++`, `consolidado`) y borra el ítem de la lista de Spam.
    2. **No es spam** (*Integrar a Pendientes* o *Corregir*): degrada/desactiva el patrón en `dismissed_patterns` que la atrapó, elimina de Spam y la integra en **Pendientes** (o abre `CorrectionDialog` para corregirla y aprenderla en `learned_patterns`).

### RF-4: Ventana Cruzada Adaptativa de 5 Minutos y Cerebro IA con Contexto Real
- `NotificationBatchCoordinator` agrupa notificaciones no-spam en una ventana de **5 minutos** (o tope de 6 eventos) en segundo plano para descubrir patrones cruzados (ej. débito Nu + crédito Nequi = transferencia propia; pedido Rappi + cobro RappiCard = 1 gasto con comercio real + cuenta real).
- **Flush inmediato en primer plano:** al abrir Moneo / entrar a Pendientes (o manualmente en tests), procesa el lote acumulado de inmediato sin esperar 5 min, manteniendo un **contexto deslizante de los últimos 5–10 min** (pendientes + confirmados recientes) para seguir cruzando eventos que lleguen después.
- **Sobre tipado y presupuesto fijo `O(1)` de tokens:**
  - `CompactSimilarityIndex` selecciona únicamente **Top-3 patrones confirmados** + **Top-2 patrones de spam de esa app** + **contexto cruzado (máx. 3 líneas)** + **cuentas reales del usuario** (nombre, tipo, `last4`) + **categorías reales de `CategoryService`**.
  - En Gemma 4 E2B local, el prompt se acota estrictamente a **≤ 550 tokens de entrada + 160 salida** (`maxTokens: 1024`) usando `AiFinancialTools.fitToTokenBudget`.
  - La IA responde JSON completo: `is_transaction`, `spam_reason`, `classification`, `amount`, `merchant`, `description`, `category`, `account_name`, `destination_account`, `confidence`, `strategic_note`.
  - Si `is_transaction == false`, la notificación se enruta a la pestaña **Spam** (5 días) sin ensuciar Pendientes.
- **Validación cruzada Post-IA:**
  - El `amount` devuelto por la IA se verifica contra los montos presentes en la notificación (si diverge, prevalece el monto verificado del parser con `requiresReview: true`).
  - `account_name`, `destination_account` y `category` se validan contra las listas reales del usuario (sin inventar nombres; si no coinciden, quedan `null` con `requiresReview: true`).
- **Fallback determinista offline:** si no hay IA configurada / sin internet / RAM insuficiente / timeout, usa reglas deterministas mejoradas con soporte `com.grability.rappi` (`Rappi` vs `RappiCard`), detección de transferencias y emparejamiento flexible contra `CategoryService`.

### RF-5: UX de Corrección y Feedback Loop Completo
- `CorrectionDialog` **nunca** preselecciona `_accounts.first` (NU) cuando `item.accountName == null`; muestra `"Selecciona una cuenta"` y exige selección explícita antes de guardar.
- `CorrectionDialog` empareja categorías sugeridas de forma insensible a tildes/mayúsculas contra `CategoryService`.
- `PendingTransactionsNotifier` pasa siempre `packageName` y `alias` a `LearnedPatternsService.recordConfirmation` / `recordCorrection`, y **bloquea** el guardado de nombres genéricos de banco (`"Nu Colombia"`, `"Rappi"`, `"Nequi"`, `"Bancolombia"`, etc.) como `merchantKey`.

### RF-6: Coordinador Único y Optimización de RAM para Gemma 4 E2B
- `LocalGemmaCoordinator` centraliza la única instancia activa de `FlutterGemma` con exclusión mutua (*mutex*) entre `AiChatService` y `DefaultGemmaInferenceClient`.
- Antes de cargar Gemma local para clasificar un lote, consulta `DeviceCapabilityService.check()`: si `lowMemory == true` o `availRAMGB < 1.8`, omite la carga local y usa el fallback determinista (evitando OOM).
- Usa `maxTokens: 1024` y timeout realista (`18s` en local) y **descarga el modelo (`close()`) inmediatamente al finalizar el lote** si el Chat no está activo, y también ante `didHaveMemoryPressure` / pausa de la app.
- Si la IA Principal es Cloud o Simulador, Gemma local mantiene **0 MB RAM**.

---

## 3. Comandos de Verificación (Docker Obligatorio)

```bash
DOCKER_HOST="unix:///var/run/docker.sock" docker-compose up -d flutter-env
DOCKER_HOST="unix:///var/run/docker.sock" docker-compose exec -T flutter-env dart analyze
DOCKER_HOST="unix:///var/run/docker.sock" docker-compose exec -T flutter-env flutter test --no-pub -j 1 test/features/notifications/
```

---

## 4. Restricciones Inviolables (Boundaries)

- **Prohibido modificar Archivos Protegidos:** `lib/data/transaction_service.dart`, `lib/data/credit_card_calculator.dart`, `lib/data/model/*.g.dart`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, `lib/core/security/*`.
- **Prohibido commits directos en `main`.**
- **Privacidad:** nunca capturar ni registrar diagnósticos de apps fuera de la whitelist; en modo Local/Simulador 0 tráfico de red; en modo Cloud usar solo la IA Principal que el usuario configuró y el sobre sanitizado (`<notificacion_no_confiable>`).
- **Aislamiento contable:** ni `pending_notifications` ni `notification_spam_items` alteran jamás saldos reales ni la caja Hive `'data'`.
