# Desglose de Tareas de Implementación — Sprint 1: Notificaciones Bancarias Offline

> **Módulo:** `sprint-1-notificaciones`  
> **Fase:** TASKS (Spec Kit + EGM)  
> **Fecha:** 2026-11-13  
> **Documentos predecesores:** [.specify/sprint-1-notificaciones/spec.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/.specify/sprint-1-notificaciones/spec.md) y [.specify/sprint-1-notificaciones/plan.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/.specify/sprint-1-notificaciones/plan.md)  
> **Regla rectora:** Ninguna tarea modificará archivos protegidos sin autorización humana previa.

---

## Grafo de Dependencias y Orden de Ejecución

```
T01 (Modelos de Dominio y Puertos)
 │
 ├──► T02 (Whitelist e Ingestión con Dedup SHA-256)
 │
 ├──► T03 (Parser Genérico y Filtro Anti-Fraude)
 │     │
 │     └──► T04 (Servicio de Learned Patterns - Hive)
 │           │
 │           └──► T05 (Clasificador Jerárquico Etapas 0 a 3)
 │                 │
 └─────────────────┴──► T06 (Notifier de Transacciones Pendientes y "Aceptar Todo")
                         │
                         └──► T07 (UI de Bandeja de Pendientes y Diálogo de Corrección)
                               │
                               └──► T08 (Suite de Pruebas de Integración y Validadores Deterministas)
```

---

## Lista Detallada de Tareas

### T01: Definición de Modelos de Dominio y Puertos Hexagonales
- **Objetivo:** Crear los contratos de datos en Dart 3 con clases selladas (`sealed classes`), enums e interfaces desacopladas.
- **Archivos a crear:**
  - `lib/features/notifications/domain/models/notification_event.dart`
  - `lib/features/notifications/domain/models/notification_parse_result.dart`
  - `lib/features/notifications/domain/models/transaction_classification.dart`
  - `lib/features/notifications/domain/models/pending_transaction_item.dart`
  - `lib/features/notifications/domain/models/learned_pattern.dart`
  - `lib/features/notifications/domain/ports/notification_source_port.dart`
  - `lib/features/notifications/domain/ports/transaction_execution_port.dart`
- **Criterios de Aceptación:**
  - `NotificationParseResult` modelado como `sealed class` con subtipos `ParsedTransaction`, `SuspiciousNotification` y `UnparseableNotification`.
  - Serialización manual `toJson()` y `fromJson()` en cada modelo sin dependencias de generadores en archivos existentes.
  - Puertos abstractos sin dependencias de `dart:io` ni código nativo.
- **Comando de verificación:** `docker-compose exec flutter-env dart analyze lib/features/notifications/domain/`

---

### T02: Servicio de Whitelist de Bancos e Ingestión con Deduplicación
- **Objetivo:** Implementar la capa de ingestión que filtra notificaciones por paquete y descarta duplicados en ventana de 5 minutos mediante hash SHA-256.
- **Archivos a crear:**
  - `lib/features/notifications/services/bank_whitelist_service.dart`
  - `lib/features/notifications/services/notification_ingestion_service.dart`
  - `lib/features/notifications/adapters/simulated_notification_source.dart`
  - `test/features/notifications/services/notification_ingestion_test.dart`
- **Criterios de Aceptación:**
  - Whitelist preconfigurada con 8 entidades bancarias y billeteras colombianas comunes.
  - Eventos con mismo paquete, título, cuerpo y ventana de 5 minutos generan el mismo hash y se descartan.
  - `simulated_notification_source` permite emitir streams controlados para testing.
- **Comando de verificación:** `docker-compose exec flutter-env flutter test test/features/notifications/services/notification_ingestion_test.dart`

---

### T03: Parser Genérico Multi-Moneda y Detector Anti-Fraude (`moneo-notification-parser`)
- **Objetivo:** Implementar la extracción agnóstica de monto, comercio, fecha y cuenta, junto con el bloqueo incondicional de URLs, acortadores y textos OTP.
- **Archivos a crear:**
  - `lib/features/notifications/services/notification_parser.dart`
  - `test/features/notifications/services/notification_parser_test.dart`
- **Criterios de Aceptación:**
  - Soporte de formatos numéricos con `CurrencyHelper` (COP miles con punto, USD miles con coma).
  - Bloqueo estricto de links (`http://`, `https://`, `bit.ly`, `tinyurl.com`, `.xyz`, etc.): produce `SuspiciousNotification` con `confidence = 0.0` y `autoProcessable = false`.
  - Detección de mensajes OTP: genera `UnparseableNotification` con `monto = null`.
  - Salida compatible con el esquema validado por el script de la skill.
- **Comando de verificación:**
  ```bash
  docker-compose exec flutter-env flutter test test/features/notifications/services/notification_parser_test.dart
  uv run .agents/skills/moneo-notification-parser/scripts/validate_parser_output.py --self-test
  ```

---

### T04: Servicio de Persistencia para Patrones Aprendidos (`learned_patterns`)
- **Objetivo:** Implementar el almacenamiento local en Hive para recordar categorías y cuentas asociadas a comercios confirmados por el usuario.
- **Archivos a crear:**
  - `lib/features/notifications/services/learned_patterns_service.dart`
  - `test/features/notifications/services/learned_patterns_service_test.dart`
- **Criterios de Aceptación:**
  - Apertura y gestión de la caja Hive `"learned_patterns"`.
  - Normalización de comercio (lowercase, sin acentos ni números de sucursal).
  - Método `recordConfirmation(merchant, ...)` incrementa `confirmations`.
  - Método `recordCorrection(merchant, ...)` actualiza asignación, resetea `confirmations = 1` y marca `lastCorrectedAt`.
- **Comando de verificación:** `docker-compose exec flutter-env flutter test test/features/notifications/services/learned_patterns_service_test.dart`

---

### T05: Clasificador Jerárquico en 4 Etapas (`moneo-transaction-classifier`)
- **Objetivo:** Orquestar la toma de decisiones contables evaluando Anti-Fraude → Aprendizaje Local → Reglas Deterministas → Fallback Gemma.
- **Archivos a crear:**
  - `lib/features/notifications/services/gemma_classifier_adapter.dart`
  - `lib/features/notifications/services/transaction_classifier.dart`
  - `test/features/notifications/services/transaction_classifier_test.dart`
- **Criterios de Aceptación:**
  - Etapa 0 bloquea inmediatamente si hay sospecha de fraude o urgencia (`createTransaction: false`).
  - Etapa 1 usa `LearnedPatternsService` sin invocar a Gemma.
  - Etapa 2 clasifica transferencias propias, ingresos y gastos según cuentas del usuario y palabras clave.
  - Etapa 3 invoca `GemmaClassifierAdapter` únicamente si `confidence < 0.80`; si no está disponible o falla, degrada a `fallback_ambiguous` con `requiresReview: true`.
- **Comando de verificación:**
  ```bash
  docker-compose exec flutter-env flutter test test/features/notifications/services/transaction_classifier_test.dart
  uv run .agents/skills/moneo-transaction-classifier/scripts/validate_classification.py --self-test
  ```

---

### T06: Gestión de Estado de la Bandeja de Pendientes y "Aceptar Todo"
- **Objetivo:** Implementar el `ChangeNotifier` para la bandeja de pendientes, respaldado en caja Hive `pending_notifications` y con filtro estricto de alta confianza para lote.
- **Archivos a crear:**
  - `lib/features/notifications/presentation/notifiers/pending_transactions_notifier.dart`
  - `lib/features/notifications/adapters/mock_transaction_execution_adapter.dart`
  - `test/features/notifications/presentation/notifiers/pending_transactions_notifier_test.dart`
- **Criterios de Aceptación:**
  - Aislamiento contable: ningún ítem pendiente altera saldos en `SharedPreferences` ni escribe en caja `'data'`.
  - "Aceptar todo" procesa exclusivamente ítems con `confidence >= 0.85`, `requiresReview == false`, `classification != 'sospechosa'` y cuenta asignada.
  - Ítems sospechosos o con `confidence < 0.85` permanecen en la bandeja.
  - Las acciones de Confirmar y Corregir actualizan `LearnedPatternsService`.
- **Comando de verificación:**
  ```bash
  docker-compose exec flutter-env flutter test test/features/notifications/presentation/notifiers/pending_transactions_notifier_test.dart
  uv run .agents/skills/moneo-feedback-loop/scripts/verify_feedback_invariants.py --self-test
  ```

---

### T07: Componentes de UI de la Bandeja de Transacciones Pendientes
- **Objetivo:** Construir la interfaz de usuario de la bandeja cumpliendo con la guía de estilo (`AppColors`, tema oscuro, accesibilidad y formato de moneda).
- **Archivos a crear:**
  - `lib/features/notifications/presentation/widgets/suspicious_badge.dart`
  - `lib/features/notifications/presentation/widgets/pending_transaction_card.dart`
  - `lib/features/notifications/presentation/widgets/correction_dialog.dart`
  - `lib/features/notifications/presentation/screens/pending_transactions_screen.dart`
  - `test/features/notifications/presentation/screens/pending_transactions_screen_test.dart`
- **Criterios de Aceptación:**
  - Uso estricto de colores de `AppColors` (fondo `0xFF1F2639`, acento `0xFF52E2FF`).
  - Tarjeta muestra comercio, monto formateado con `CurrencyHelper`, insignia de estado, y botones: Confirmar, Corregir y Descartar.
  - Diálogo de corrección permite seleccionar tipo, categoría y cuenta.
  - Widget test verifica que pulsar "Aceptar todo" aprueba los de alta confianza y mantiene visibles los sospechosos o de baja confianza.
- **Comando de verificación:** `docker-compose exec flutter-env flutter test test/features/notifications/presentation/screens/pending_transactions_screen_test.dart`

---

### T08: Suite de Integración, Análisis Estático y Validación de Invariantes
- **Objetivo:** Integrar el pipeline completo desde la emisión de eventos simulados hasta la actualización de la bandeja y ejecutar los quality gates.
- **Archivos a crear / modificar:**
  - `test/features/notifications/integration/notification_flow_integration_test.dart`
- **Criterios de Aceptación:**
  - Simulación de flujo end-to-end (ingesta -> parseo -> clasificación -> confirmación en lote) ejecutada con éxito.
  - Verificación de que `lib/data/transaction_service.dart`, `android/app/AndroidManifest.xml` y demás archivos protegidos no han sufrido modificaciones.
  - `dart analyze` sin errores ni advertencias en el nuevo módulo.
- **Comandos de verificación:**
  ```bash
  docker-compose exec flutter-env dart analyze lib/features/notifications/
  docker-compose exec flutter-env flutter test test/features/notifications/
  uv run .agents/skills/moneo-notification-parser/scripts/validate_parser_output.py --self-test
  uv run .agents/skills/moneo-transaction-classifier/scripts/validate_classification.py --self-test
  uv run .agents/skills/moneo-feedback-loop/scripts/verify_feedback_invariants.py --self-test
  ```
