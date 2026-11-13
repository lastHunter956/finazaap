# Especificación Funcional y Técnica — Sprint 1: Notificaciones Bancarias Offline

> **Módulo:** `sprint-1-notificaciones`  
> **Estado:** Borrador listo para revisión humana (FASE 1 - SPEC)  
> **Fecha:** 2026-11-13  
> **Autores / Roles:** Subagente Especialista en Especificación (Spec Kit + EGM)  
> **Referencias:** [PROJECT_AUDIT.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/discovery/PROJECT_AUDIT.md), [AGENTS.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/AGENTS.md), Skills de dominio (`moneo-notification-parser`, `moneo-transaction-classifier`, `moneo-feedback-loop`).

---

## Supuestos Iniciales Declarados (Assumptions)

1. **Sprint 1 es 100% Dart/Flutter en arquitectura desacoplada:** No se implementará código nativo en Kotlin ni se modificarán manifiestos (`android/`) en este sprint. La entrada de eventos de notificación se modela a través de una abstracción (`NotificationSourcePort` / `NotificationIngestionService`) con implementación en memoria y simulador de eventos para pruebas y desarrollo.
2. **Aislamiento total de archivos protegidos:** `lib/data/transaction_service.dart` **NO** será modificado. La bandeja de pendientes interactuará con el registro contable únicamente a través de una interfaz de aplicación desacoplada (`TransactionExecutionPort`), cuya invocación real a `TransactionService.processTransaction` queda detrás de confirmación manual explícita.
3. **Privacidad estricta 100% offline:** Ningún texto crudo, monto o metadato de notificación bancaria saldrá del dispositivo hacia redes externas, ni se emitirá en consolas de producción con `print()`.
4. **Persistencia aislada para el Sprint 1:** Las transacciones pendientes y los patrones aprendidos se almacenan en cajas Hive independientes (`pending_notifications` y `learned_patterns`), garantizando que la caja principal `'data'` y la lista de cuentas en `SharedPreferences('accounts')` permanezcan intactas hasta que el usuario confirme una transacción.
5. **Entorno de ejecución de tests:** Flutter y Dart corren dentro del contenedor Docker `finazaap-flutter` (`docker-compose exec flutter-env flutter test`).

---

## 1. Objetivo y Alcance

### 1.1 Declaración del Problema
Moneo (`finazaap`) requiere registrar gastos e ingresos de forma ágil sin obligar al usuario a digitar manualmente cada compra o transferencia. Sin embargo, las notificaciones bancarias de Android presentan alta variabilidad de formatos, riesgo de phishing/fraude, ambigüedades en montos (formatos con coma vs punto) y riesgo de desbalancear los saldos si se procesan automáticamente sin supervisión.

### 1.2 Objetivo del Sprint 1
Diseñar e implementar el núcleo en Dart/Flutter para:
1. Ingerir y filtrar eventos de notificación mediante una whitelist configurable de paquetes bancarios y billeteras.
2. Parsear el texto crudo de forma genérica y tipada (sin plantillas rígidas por banco), bloqueando enlaces sospechosos (`moneo-notification-parser`).
3. Clasificar el movimiento en `gasto`, `ingreso`, `transferencia-propia` o `sospechosa` mediante una jerarquía estricta: Anti-fraude → Aprendizaje local (`learned_patterns`) → Reglas deterministas → Fallback opcional on-device Gemma (`moneo-transaction-classifier`).
4. Proveer una bandeja de **transacciones pendientes** con opciones de **Confirmar**, **Corregir**, **Descartar** y **"Aceptar todo"** (solo para alta confianza `>= 0.85`), actualizando el aprendizaje continuo sin alterar saldos reales mientras estén pendientes (`moneo-feedback-loop`).

### 1.3 Alcance (In Scope vs Out of Scope)

| En Alcance (Sprint 1) | Fuera de Alcance (Diferido a Sprint 2 o posterior) |
| :--- | :--- |
| Modelos de dominio tipados (`NotificationEvent`, `NotificationParseResult`, `ClassificationResult`, `PendingTransactionItem`, `LearnedPattern`). | Servicio nativo Android `NotificationListenerService` en Kotlin (`MainActivity.kt`, `AndroidManifest.xml`). |
| Servicio de ingestión y cola en Dart con whitelist configurable y deduplicación por hash temporal (`SHA-256`). | Pantalla de configuración del sistema Android para otorgar permiso `BIND_NOTIFICATION_LISTENER_SERVICE`. |
| Parser genérico de montos (`CurrencyHelper`), comercios, fechas, cuentas y anti-fraude por links/acortadores. | Modificación de `lib/data/transaction_service.dart` o `lib/data/credit_card_calculator.dart`. |
| Clasificador jerárquico Etapas 0 a 3 con soporte para caja Hive `learned_patterns` y adaptador seguro para Gemma (`flutter_gemma`). | Regeneración de modelos Hive existentes (`add_date.g.dart`, `responsibility.g.dart`). |
| UI de Bandeja de Pendientes (Dark theme con `AppColors`), filtros, detalle de tarjeta y diálogo de corrección. | Cifrado a nivel de bloque en disco (`HiveAesCipher`) para la base de datos completa de Moneo. |
| Modo "Aceptar todo" condicionado por umbral estricto (`confidence >= 0.85` e invariantes anti-fraude). | Migración de monedas históricas o sincronización cloud. |
| Suite completa de pruebas unitarias, widget tests y validadores deterministas en Docker. | Flujo de cuotas automáticas complejas de tarjetas de crédito. |

---

## 2. Tech Stack y Comandos de Verificación

- **Lenguaje:** Dart `>=3.0.0 <4.0.0` (Dart 3 sealed classes, switch exhaustivo y pattern matching).
- **Framework:** Flutter 3.x (ejecutado en contenedor Docker `finazaap-flutter`).
- **Persistencia local del módulo:** `hive` / `hive_flutter` (cajas dedicadas `pending_notifications` y `learned_patterns`).
- **Moneda y formato:** `CurrencyHelper` (`lib/utils/currency_helper.dart`), `intl`.
- **Diseño visual:** `AppColors` (`lib/themes/app_colors.dart`), Material 3.
- **Herramientas de validación de skills:** Scripts deterministas Python en `.agents/skills/*/scripts/`.

### Comandos de Ejecución Obligatoria (Docker)

```bash
# Iniciar contenedor Docker (si no está activo)
make up

# Análisis estático y formato
docker-compose exec flutter-env dart analyze
docker-compose exec flutter-env dart format --output=none --set-exit-if-changed .

# Ejecución de tests unitarios del módulo
docker-compose exec flutter-env flutter test test/features/notifications/

# Validación determinista de invariantes (scripts de skills instaladas)
uv run .agents/skills/moneo-notification-parser/scripts/validate_parser_output.py --self-test
uv run .agents/skills/moneo-transaction-classifier/scripts/validate_classification.py --self-test
uv run .agents/skills/moneo-feedback-loop/scripts/verify_feedback_invariants.py --self-test
```

---

## 3. Estructura de Proyecto Propuesta

Todo el código nuevo se organiza dentro de un módulo vertical y modular en `lib/features/notifications/` para evitar colisiones con el código heredado:

```
lib/
└── features/
    └── notifications/
        ├── domain/
        │   ├── models/
        │   │   ├── notification_event.dart            # Evento crudo normalizado
        │   │   ├── notification_parse_result.dart     # Sealed class: Parsed, Suspicious, Unparseable
        │   │   ├── transaction_classification.dart    # Resultado de clasificación (etapas 0-3)
        │   │   ├── pending_transaction_item.dart      # Item en bandeja pendiente
        │   │   └── learned_pattern.dart               # Modelo de patrón aprendido
        │   └── ports/
        │       ├── notification_source_port.dart      # Abstracción para recibir notificaciones
        │       └── transaction_execution_port.dart    # Abstracción para registrar en Moneo
        ├── services/
        │   ├── bank_whitelist_service.dart            # Whitelist de paquetes y metadatos
        │   ├── notification_ingestion_service.dart    # Cola, deduplicación SHA-256
        │   ├── notification_parser.dart               # Parser genérico multi-moneda + anti-fraude
        │   ├── transaction_classifier.dart            # Clasificador jerárquico 4 etapas
        │   ├── learned_patterns_service.dart          # Gestión de caja Hive "learned_patterns"
        │   └── gemma_classifier_adapter.dart          # Fallback seguro con flutter_gemma / no-op
        └── presentation/
            ├── notifiers/
            │   └── pending_transactions_notifier.dart # ChangeNotifier para la bandeja
            ├── screens/
            │   └── pending_transactions_screen.dart   # Vista de bandeja pendientes
            └── widgets/
                ├── pending_transaction_card.dart      # Tarjeta individual con insignias y acciones
                ├── correction_dialog.dart             # Diálogo modal para corregir tipo/categoría/cuenta
                └── suspicious_badge.dart              # Indicador visual de alerta de seguridad

test/
└── features/
    └── notifications/
        ├── domain/
        ├── services/
        │   ├── notification_parser_test.dart          # Tests multi-moneda, fraudes y límites
        │   ├── transaction_classifier_test.dart       # Jerarquía 0-3, learned patterns y fallback
        │   └── notification_ingestion_test.dart       # Deduplicación y whitelist
        └── presentation/
            └── pending_transactions_screen_test.dart  # Widget tests de bandeja y "Aceptar todo"
```

---

## 4. Requerimientos Funcionales Detallados

### RF-01: Ingestión, Whitelist y Deduplicación
1. **Whitelist bancaria configurable:** El sistema mantiene una lista predeterminada de identificadores de paquetes bancarios y billeteras de uso común (ej. Colombia: `com.bancolombia.personas`, `com.nequi.MobileApp`, `com.davivienda.billetera`, `co.daviplata`, `com.nu.production`, `co.com.bbva.mb`, `com.scotiabank.colpatria`, `com.bancofalabella.mobile`). El usuario puede activar/desactivar entidades desde la configuración del servicio.
2. **Deduplicación determinista:** Cada notificación genera un hash determinista:
   $$\text{dedupHash} = \text{SHA256}(\text{package} + \text{rawText} + \lfloor\text{timestamp} / 300\text{s}\rfloor)$$
   Si un evento con el mismo hash ya existe en la cola o en pendientes dentro de la ventana de 5 minutos, se descarta silenciosamente.
3. **Manejo de permisos/estado:** Si la fuente nativa no está habilitada o se encuentra simulada, el servicio expone un estado explícito `NotificationSourceStatus.disconnected` sin provocar excepciones ni bloqueos en la app.

### RF-02: Parser Genérico Multi-Moneda y Anti-Fraude (`moneo-notification-parser`)
1. **Prohibición de plantillas fijas por banco:** El parsing se basa exclusivamente en heurísticas genéricas de texto y validación cruzada.
2. **Monto y moneda:**
   - Detecta símbolos (`$`, `COP`, `USD`, `MXN`, `EUR`, etc.).
   - Utiliza la configuración activa de `CurrencyHelper` para resolver la puntuación decimal y de miles.
   - Validación cruzada: si un número posee formato `45.000` con exactamente 3 dígitos tras el punto y contexto COP, se interpreta como $45,000.00, no como 45.0. Si la puntuación resulta ambigua (ej. `1.234`), se castiga la confianza (`confidence = 0.50`) y se marca `requires_review = true`.
3. **Detección Anti-Fraude Estricta (Invariante No Negociable):**
   - Escanea título y cuerpo buscando cualquier URL (`http://`, `https://`, `www.`), acortador (`bit.ly`, `tinyurl.com`, `t.co`, `cutt.ly`, `rb.gy`, `wa.me/`) o dominio de riesgo (`.xyz`, `.top`, `.click`).
   - Si se detecta un enlace:
     - `status: "sospechosa"`
     - `tipo: "sospechosa"`
     - `confidence: 0.0`
     - `requires_review: true`
     - `auto_processable: false`
     - Bandera agregada a `flags: ["anti_fraud_link_detected"]`.
4. **Comercio y Cuenta:**
   - Extrae el nombre del comercio posterior a conectores comunes (`en `, `a `, `de `, `comercio `) sanitizando horas y asteriscos.
   - Identifica últimos 4 dígitos (`*1234`, `terminada en 1234`, `tarjeta 1234`) y alias de producto (`ahorros`, `corriente`, `crédito`).
5. **Textos no transaccionales (OTP / Marketing):**
   - Si el texto contiene patrones de un solo uso (`"código de seguridad"`, `"código de verificación"`, `"OTP"`, `"clave dinámica"`), el parser genera `status: "unparseable"`, `monto: null`, `requires_review: true`. Prohibido extraer el código numérico como si fuera un monto financiero.

### RF-03: Clasificador Jerárquico en 4 Etapas (`moneo-transaction-classifier`)
El clasificador evalúa en orden estricto y se detiene en la primera coincidencia concluyente:

```
[Entrada JSON Parseado]
          │
          ▼
┌───────────────────────────────────────────────┐
│ Etapa 0: Anti-Fraude                          │
│ ¿Link detectado O palabras de urgencia/phish? │
└───────┬───────────────────────────────┬───────┘
       SÍ                              NO
        │                               │
        ▼                               ▼
[Bloqueo Sospechosa]         ┌─────────────────────────────────────┐
(Conf=0.0, ReqRev=true,      │ Etapa 1: learned_patterns (Hive)   │
 No Tx)                      │ ¿Comercio normalizado en historial? │
                             └──────┬───────────────────────┬──────┘
                                   SÍ                      NO
                                    │                       │
                                    ▼                       ▼
                         [Clasificación Aprendida] ┌───────────────────────────────┐
                         (Conf >= 0.85, ReqRev=f)  │ Etapa 2: Reglas Deterministas │
                                                   │ ¿Transferencia propia /       │
                                                   │  Gasto / Ingreso unívoco?    │
                                                   └──────┬────────────────┬───────┘
                                                         SÍ               NO (Conf < 0.80)
                                                          │                │
                                                          ▼                ▼
                                                [Clasificación Regla] ┌─────────────────────────────┐
                                                (Conf >= 0.80)        │ Etapa 3: Respaldo Gemma     │
                                                                      │ ¿Gemma disponible y >=4GB? │
                                                                      └──────┬───────────────┬──────┘
                                                                            SÍ              NO
                                                                             │               │
                                                                             ▼               ▼
                                                                        [Gemma Pred]   [fallback_ambiguous]
                                                                                       (ReqRev=true)
```

1. **Etapa 0 (Anti-Fraude):** Si `status == "sospechosa"`, o si el texto contiene palabras clave de ingeniería social (`"cuenta bloqueada"`, `"suspensión inmediata"`, `"actualiza tus datos ahora"`, `"evita el bloqueo"`, `"ingresa aquí"`, `"último aviso"`), se asigna:
   - `classification: "sospechosa"`
   - `moneo_type: null`
   - `create_transaction: false`
   - `decision_source: "anti_fraud"`
   - `requires_review: true`
2. **Etapa 1 (Aprendizaje Local):** Consulta la caja Hive `"learned_patterns"` por `comercio_normalizado`. Si existe coincidencia con `>= 1` confirmaciones, asigna categoría, tipo y cuenta con alta confianza (`confidence = min(0.95, 0.85 + confirmations * 0.02)`), `decision_source: "learned_patterns"`. No se consulta a Gemma.
3. **Etapa 2 (Reglas Deterministas):**
   - **Transferencia propia:** Si tanto el origen como el destino coinciden con cuentas locales del usuario registradas en Moneo, se clasifica como `transferencia-propia` (`moneo_type: "Transfer"`).
   - **Ingreso:** Verbos clave de abono (`recibiste`, `depósito`, `abono`, `nómina`, `consignación`) → `ingreso` (`moneo_type: "Income"`).
   - **Gasto:** Verbos de débito (`compra`, `pago`, `débito`, `retiro`, `cargo`) → `gasto` (`moneo_type: "Expenses"`). Asigna categoría preliminar por palabras clave de comercio.
   - Si la asignación es clara: `confidence = 0.82`, `requires_review = false`, `decision_source: "deterministic_rules"`.
4. **Etapa 3 (Fallback Gemma On-Device):**
   - Se invoca **únicamente** si `confidence < 0.80` o la clasificación es ambigua.
   - Si `flutter_gemma` está disponible y con soporte de memoria, ejecuta inferencia local sin PII solicitando `{classification, category, confidence}`.
   - Si Gemma no está disponible, falla o el dispositivo tiene recursos limitados: asigna `decision_source: "fallback_ambiguous"`, `requires_review: true`, conservando la mejor hipótesis para resolución en la bandeja.

### RF-04: Bandeja de Transacciones Pendientes y Ciclo de Feedback (`moneo-feedback-loop`)
1. **Aislamiento Absoluto de Saldos:**
   - Mientras una notificación reside en la bandeja de pendientes, **no** existe en la caja `'data'` ni modifica `SharedPreferences('accounts')`.
   - El saldo real de las cuentas del usuario no se altera en ningún caso durante la ingesta o clasificación.
2. **Interfaz de la Bandeja:**
   - Paleta de diseño restringida a `AppColors` (fondo oscuro `0xFF1F2639`, acento `0xFF52E2FF`, advertencia ámbar, peligro rojo).
   - Tarjeta individual con comercio sanitizado, monto formateado mediante `CurrencyHelper`, insignia de estado (`Sospechosa` / `Revisión requerida` / `Alta confianza`), tipo propuesto y cuenta asignada.
   - Botones de acción directa:
     - **Confirmar:** Aprueba la transacción propuesta. Actualiza `learned_patterns` (+1 confirmación) y remueve el ítem de la bandeja. En este Sprint 1 la ejecución se delega a `TransactionExecutionPort` (simulable / mockeable en tests).
     - **Corregir:** Abre modal de edición rápida para cambiar tipo (`Income`/`Expenses`/`Transfer`), categoría y cuenta de Moneo. Al guardar, actualiza el patrón en `learned_patterns` con `confirmations = 1` y marca `last_corrected_at`.
     - **Descartar:** Elimina el ítem de la bandeja pendiente de forma inmediata, sin alterar saldos ni modificar `learned_patterns`.
3. **Modo "Aceptar todo" (Filtro Estricto de Lote):**
   - Al pulsar **"Aceptar todo"**, el sistema evalúa cada ítem de la bandeja contra el siguiente predicado estricto:
     $$\text{Aceptable} \iff (\text{classification} \neq \text{"sospechosa"}) \land (\neg\text{requires\_review}) \land (\text{confidence} \ge 0.85) \land (\text{account\_name} \neq \text{null})$$
   - Los ítems sospechosos, de baja confianza (`confidence < 0.85`) o con cuenta no identificada **permanecen intactos en la bandeja**.
   - La interfaz muestra una notificación clara: *"Se aceptaron N movimientos. M requieren revisión manual."*

---

## 5. Criterios de Aceptación Medibles

| Criterio | Métrica / Umbral | Método de Verificación |
| :--- | :--- | :--- |
| **Invariante Anti-Fraude por Links** | 100% de notificaciones con URLs o acortadores terminan en `status: "sospechosa"`, `confidence: 0.0`, `auto_processable: false`, `requires_review: true`. | Script `validate_parser_output.py` y suite de unit tests. |
| **Invariante Anti-Fraude por Urgencia** | 100% de notificaciones con frases de coacción/phishing terminan en `classification: "sospechosa"`, `create_transaction: false`. | Script `validate_classification.py` y suite de unit tests. |
| **Umbral de Revisión Individual** | Si `confidence < 0.80`, forzosamente `requires_review == true` y `auto_processable == false`. | Script `validate_parser_output.py` e invariante Dart. |
| **Umbral de Lote "Aceptar todo"** | Solo ítems con `confidence >= 0.85`, `requires_review == false`, no sospechosos y cuenta no nula se procesan en lote. Ítems `< 0.85` o sospechosos nunca se procesan en lote. | Script `verify_feedback_invariants.py` y test de widget. |
| **Aislamiento Contable** | Cero escrituras en caja Hive `'data'` y cero mutaciones en `SharedPreferences('accounts')` mientras el ítem esté en pendientes o al ser descartado. | Test unitario con inspección de mocks/cajas. |
| **Deduplicación Temporal** | 100% de eventos duplicados en ventana de 5 minutos son descartados sin generar duplicados en la cola. | Test unitario `notification_ingestion_test.dart`. |
| **Privacidad Offline y Logs** | Cero llamadas HTTP/WebSockets y cero `print()` en producción que impriman texto crudo o montos. | `dart analyze` y auditoría de código. |
| **Regeneración de Aprendizaje** | Al confirmar o corregir un comercio, la caja Hive `"learned_patterns"` registra inmediatamente el nuevo mapeo. | Test de persistencia en `learned_patterns_service_test.dart`. |

---

## 6. Casos de Error y Fallback Explícitos

1. **Notificación con link acortado o sospechoso (ej. `"Transacción rechazada. Revisa aquí: bit.ly/banco-alerta"`):**
   - Parser detecta `bit.ly`.
   - Produce `status: "sospechosa"`, `confidence: 0.0`, `requires_review: true`.
   - Clasificador Etapa 0 bloquea: `classification: "sospechosa"`, `create_transaction: false`.
   - UI de la bandeja muestra insignia roja `[Sospechosa / Alerta de Fraude]` y botón de "Aceptar todo" la excluye automáticamente.
2. **Texto no financiero / OTP (ej. `"Tu código de seguridad para transferir es 839201. Vence en 5 minutos"`):**
   - Parser detecta patrón OTP.
   - Produce `status: "unparseable"`, `monto: null`, `requires_review: true`.
   - Se descarta o se notifica como no financiero sin crear montos ficticios de $839,201.
3. **Monto ambiguo sin moneda explícita (ej. `"Compra aprobada por 1.500"`):**
   - Sin contexto de moneda unívoco, el parser penaliza `confidence = 0.50` y activa `requires_review: true`.
   - Clasificador no alcanza el umbral de 0.80 y solicita revisión manual.
4. **Fallo de memoria o indisponibilidad de Gemma (OOM / dispositivo gama baja):**
   - El adaptador `GemmaClassifierAdapter` envuelve la llamada en un bloque `try/catch` con timeout estricto de 3 segundos.
   - Ante excepción o runtime no listo, conmuta silenciosamente a `decision_source: "fallback_ambiguous"`, `requires_review: true`. La app nunca se cierra ni congela el hilo principal.
5. **Permiso de notificación no otorgado o denegado en Android:**
   - La capa Dart detecta estado inactivo en `NotificationSourcePort`.
   - La pantalla de bandeja muestra un banner informativo accesible recomendando activar la fuente, manteniendo la app 100% operativa.
6. **Notificación duplicada por reintento de la red celular:**
   - Deduplicador SHA-256 reconoce el hash temporal repetido y descarta el evento.

---

## 7. Lista Explícita de Archivos Protegidos (Sprint 1)

Queda **terminantemente prohibido** modificar los siguientes archivos durante la ejecución del Sprint 1 sin aprobación previa y expresa del usuario humano:

| Archivo Protegido | Motivo Crítico de Protección | Tratamiento en Sprint 1 |
| :--- | :--- | :--- |
| `lib/data/transaction_service.dart` | Única puerta de entrada para saldos en `SharedPreferences` y sincronización con `ResponsibilityService` y `Hive`. Riesgo de corrupción contable. | **No se modifica.** Se define una abstracción `TransactionExecutionPort` en el nuevo módulo para desacoplar el consumo. |
| `lib/data/credit_card_calculator.dart` | Fuente de verdad única para deuda y cuotas de tarjetas de crédito. | **No se modifica.** Las notificaciones de tarjeta de crédito solo mapean nombre de cuenta y monto en este sprint. |
| `lib/data/model/*.g.dart` | Adaptadores Hive generados por `build_runner` (`add_date.g.dart`, `responsibility.g.dart`). Modificarlos corrompe datos existentes. | **No se modifican.** Los nuevos modelos usan adaptadores independientes o serialización manual JSON. |
| `android/app/build.gradle` | Configuración de compilación Android, `applicationId`, firmas y versiones de SDK. | **No se modifica en Sprint 1.** Se mantiene intacto. |
| `android/app/src/main/AndroidManifest.xml` | Permisos del sistema y servicios declarados de Android. | **No se modifica en Sprint 1.** El receptor nativo queda diferido al Sprint 2. |
| `lib/core/security/*` | Cifrado (`encryption_service.dart`), llaves maestras y seguridad de PIN. | **No se modifica.** El nuevo módulo usa persistencia estándar en cajas dedicadas. |

---

## 8. Preguntas Abiertas y Decisiones para el Usuario

1. **Caja Hive para `learned_patterns`:** ¿Deseas que los patrones aprendidos (`comercio -> categoría/cuenta`) se guarden en una caja Hive abierta `"learned_patterns"` en este sprint, y pasen a caja cifrada en el sprint de hardening de seguridad?
2. **Acción de confirmación en Sprint 1:** Para el cierre de este sprint, ¿prefieres que al confirmar un ítem en la UI se invoque de prueba un adaptador mock de `TransactionExecutionPort` que verifique la llamada sin tocar saldos reales, o prefieres autorizar la integración directa con `TransactionService.processTransaction` bajo un gate de confirmación? (Recomendación: Mock/port desacoplado en Sprint 1; integración conectada en Sprint 2 tras aprobación).
3. **Persistencia de la bandeja de pendientes:** ¿La bandeja de pendientes debe persistirse en disco (caja Hive `pending_notifications`) para sobrevivir al reinicio de la app, o para el Sprint 1 es suficiente mantenerla en memoria (`ChangeNotifier`)? (Recomendación: Caja Hive para no perder notificaciones si el usuario reinicia).
