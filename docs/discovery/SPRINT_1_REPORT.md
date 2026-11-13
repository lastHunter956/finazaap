# Reporte de Sprint 1 — Notificaciones Bancarias Offline (Moneo / `finazaap`)

> **Rama de integración:** `integration/sprint-1`  
> **Fecha:** 2026-11-13  
> **Estado general:** **COMPLETADO (Listo para revisión humana y merge manual a `main`)**  
> **Regla de rama:** Sin commits ni merges directos en `main`.

---

## 1. Resumen Ejecutivo por Fases

| Fase | Agentes / Skills | Estado | Resultado |
| :--- | :--- | :---: | :--- |
| **FASE 1 — SPEC** | `especialista-spec` + `reviewer-goldfish` (EGM) | ✅ Completada | Spec, plan y tasks generados en `.specify/sprint-1-notificaciones/` y auditados con contexto fresco. |
| **FASE 2 — TASKS** | `especialista-spec` + Orquestador | ✅ Completada | Desglose T01–T08 con archivos disjuntos, criterios medibles, casos de error y asignación en worktrees `Workspace: "branch"`. |
| **FASE 3 — IMPLEMENT** | `worker-parser` + `worker-classifier` | ✅ Completada | T01 (`3566d32`), T02–T03 (`b4c4de4`), T04–T05 (`9ae5001`), T06–T08 (`7505f2d`) implementados en ramas `agent/*` aisladas. |
| **FASE 4 — REVIEW** | `reviewer-goldfish` + `revisor-seguridad` | ✅ Aprobada | `reviewer-goldfish`: **`APPROVED`**. `revisor-seguridad`: **`APROBADO CON OBSERVACIONES (PASS)`** (0 críticas/altas, 0 archivos protegidos modificados). |
| **FASE 5 — INTEGRATE** | `integrator` | ✅ Completada | Ramas `agent/*` fusionadas en `integration/sprint-1`; `dart analyze` limpio (0 issues) y ajustes de integración/tests resueltos. |
| **FASE 6 — QA** | `verificador-pruebas` + `qa-maestro` | ✅ / ⚠️ Parcial | `verificador-pruebas`: **82/82 tests Flutter pasando** + 3 validadores Python en verde. `qa-maestro`: flujo `.maestro/sprint_1_notificaciones.yaml` creado y validado; ejecución en dispositivo **`BLOCKED`** (sin emulador/JRE). |
| **FASE 7 — REPORT** | Orquestador | ✅ Completada | Este documento (`docs/discovery/SPRINT_1_REPORT.md`). |

---

## 2. Tareas Completadas y Pendientes

### Completadas en Sprint 1 (`integration/sprint-1`)
- **T01:** Modelos de dominio Dart 3 (`sealed class NotificationParseResult`, `NotificationEvent`, `TransactionClassification`, `PendingTransactionItem`, `LearnedPattern`) y puertos hexagonales (`NotificationSourcePort`, `TransactionExecutionPort`).
- **T02:** `BankWhitelistService` (20 entidades colombianas), `NotificationIngestionService` (deduplicación determinista SHA-256 en ventana de 5 min) y `SimulatedNotificationSource`.
- **T03:** `NotificationParser` genérico multi-moneda (sin plantillas fijas por banco, validación cruzada COP/USD, filtrado OTP, bloqueo estricto anti-fraude por links -> `sospechosa`).
- **T04:** `LearnedPatternsService` sobre Hive box `"learned_patterns"` con normalización de comercios y actualización por confirmación/corrección.
- **T05:** `TransactionClassifier` jerárquico estricto (Etapa 0 Anti-fraude -> Etapa 1 `learned_patterns` -> Etapa 2 Reglas deterministas -> Etapa 3 Respaldo `GemmaClassifierAdapter` con timeout 3s y fallback seguro).
- **T06:** `PendingTransactionsNotifier` (Hive box `"pending_notifications"`, aislamiento contable total, filtro estricto `"Aceptar todo"` `confidence >= 0.85` y `destinationAccount != null` para transferencias propias) + `MockTransactionExecutionAdapter`.
- **T07:** UI de bandeja de pendientes (`PendingTransactionsScreen`, `PendingTransactionCard`, `CorrectionDialog`, `SuspiciousBadge`) usando `AppColors` y `CurrencyHelper`.
- **T08:** Suite de pruebas unitarias, de widgets y de integración end-to-end (`notification_flow_integration_test.dart`).

### Pendientes para Sprint 2 (Fuera de alcance del Sprint 1 por protección de archivos)
1. **Capa nativa Android (`NotificationListenerService`):** Requiere modificar `android/app/AndroidManifest.xml` y `MainActivity.kt` (archivos protegidos/riesgo) con aprobación explícita del usuario.
2. **Conexión contable real:** Reemplazar `MockTransactionExecutionAdapter` por un adaptador hacia `TransactionService.processTransaction()` tras revisión humana.
3. **Cifrado en reposo (`HiveAesCipher`):** Integrar `lib/core/security/encryption_service.dart` para cifrar `pending_notifications` y `learned_patterns` antes de almacenar texto crudo en producción.
4. **Enlace de navegación y ejecución E2E Maestro:** Conectar `PendingTransactionsScreen` al menú principal y ejecutar `.maestro/sprint_1_notificaciones.yaml` en emulador/dispositivo Android con JRE instalado.
5. **Deuda menor de Fase 4:** Hacer `rawText` obligatorio en `ParsedTransaction` / `classify()`, unificar regex de dominios `.xyz/.top/.click` entre parser y clasificador, y reemplazar `Colors.white` por `AppColors.textPrimary` en `SnackBar` de error.

---

## 3. Resultados de Pruebas y Validaciones

### Análisis Estático (`dart analyze` en Docker `finazaap-flutter`)
- **Comando:** `docker-compose exec -T flutter-env dart analyze lib/features/notifications/ test/features/notifications/`
- **Resultado:** `No issues found!` (0 errores, 0 advertencias).

### Pruebas Unitarias, Widget e Integración (`flutter test -j 1` en Docker `finazaap-flutter`)
| Suite | Archivo | Resultado |
| :--- | :--- | :---: |
| Módulo Notificaciones (Unit + Widget + Integration E2E) | `test/features/notifications/` | **78/78 pasaron** (`+78: All tests passed!`) |
| Regresión App General | `test/widget_test.dart`, `test/ai_chat_service_test.dart` | **4/4 pasaron** (`+4: All tests passed!`) |
| **Total Flutter Test** | — | **82/82 pasaron (0 fallos)** |

### Validadores Deterministas de Skills (`uv run`)
- `.agents/skills/moneo-notification-parser/scripts/validate_parser_output.py --self-test` → **OK**
- `.agents/skills/moneo-transaction-classifier/scripts/validate_classification.py --self-test` → **OK**
- `.agents/skills/moneo-feedback-loop/scripts/verify_feedback_invariants.py --self-test` → **OK**

### Pruebas E2E Maestro (`.maestro/sprint_1_notificaciones.yaml`)
- **Artefacto:** Creado y validado sintácticamente (PyYAML, 15 pasos cubriendo permiso -> selección de app -> lectura -> bandeja -> confirmar/descartar -> aislamiento de saldos).
- **Ejecución en dispositivo:** **`BLOCKED / NO VERIFICADO EN DISPOSITIVO`** (sin emulador/dispositivo en `adb devices -l`, sin JRE en macOS host para `maestro` CLI, y UI aún desacoplada del enrutador principal en Sprint 1).

---

## 4. Conflictos Resueltos e Incidencias de Integración

1. **Conflictos de merge entre ramas `agent/*`:** **0 conflictos de archivos** gracias a la partición disjunta de archivos en FASE 2 y el uso de `Workspace: "branch"` por agente.
2. **Ajustes de integración post-merge (T01–T05):** Se ajustaron 7 pruebas unitarias iniciales en `notification_parser_test.dart` y `transaction_classifier_test.dart` (separadores COP/USD, extracción tras conectores y fixtures ambiguos para validar fallback a Gemma).
3. **Timeout en Widget Test (`FakeAsync` + Hive I/O):** `pending_transactions_screen_test.dart` sufría timeout de 10 minutos al ejecutar E/S de disco de `Hive` dentro de la zona `FakeAsync` de `testWidgets`. Se resolvió introduciendo `_InMemoryHiveBox` únicamente en el widget test (dejando `Hive` real en disco en los tests unitarios y de integración), reduciendo el tiempo de ejecución a **2 segundos**.
4. **OOM en Docker (`exit code 137`):** La ejecución concurrente por defecto de `flutter test` sobre toda la suite agotaba memoria en Docker; se estabilizó ejecutando con `-j 1`.

---

## 5. Estado de `integration/sprint-1` y Archivos Protegidos

- **Rama actual:** `integration/sprint-1` (con commits limpios y sin merge a `main`).
- **Archivos protegidos (`git diff --name-only main..HEAD`):** **0 archivos protegidos modificados** (`lib/data/transaction_service.dart`, `lib/data/credit_card_calculator.dart`, `lib/data/model/*.g.dart`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, `lib/core/security/*` permanecen 100% intactos).
- **Próximo paso:** Revisión manual por parte del usuario y merge a `main` si aprueba los cambios.
