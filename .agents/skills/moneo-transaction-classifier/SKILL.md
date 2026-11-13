---
name: moneo-transaction-classifier
description: >-
  Clasifica una notificación bancaria ya parseada en gasto, ingreso o
  transferencia-propia para Moneo, aplicando en orden estricto: anti-fraude
  (urgencia/links -> sospechosa), tabla local Hive "learned_patterns", reglas
  deterministas y Gemma (flutter_gemma) solo como respaldo ante ambigüedad.
  Usar al diseñar, implementar o auditar la clasificación de notificaciones.
---

# Moneo Transaction Classifier

Skill de dominio para clasificar el JSON producido por `moneo-notification-parser` en una intención contable válida de Moneo (`gasto` → `'Expenses'`, `ingreso` → `'Income'`, `transferencia-propia` → `'Transfer'`) o bloquearla como `"sospechosa"`.

## Skills genéricas que debes reutilizar (NO duplicar)

- **`constraint-driven-development`**: Fija umbrales y contratos no negociables (ej. `sospechosa` nunca crea transacción; Gemma no se invoca si hay match determinista).
- **`source-driven-development`**: Verifica las APIs reales de `flutter_gemma` (`^1.0.2`), `Hive` y `TransactionService.processTransaction()` en el repo antes de diseñar integraciones.
- **`test-driven-development`**: Cubre cada rama de clasificación y las pruebas negativas de fraude/urgencia.

---

## Jerarquía de Decisión (Orden Estricto)

Evalúa cada notificación parseada en este orden exacto, deteniéndote en la primera etapa concluyente:

### Etapa 0 — Anti-Fraude (Bloqueo Absoluto)
- **Condición:** El payload viene marcado como `"status": "sospechosa"`, contiene un link, **o** el texto solicita **acción urgente** / ingeniería social (ej. `"cuenta bloqueada"`, `"suspensión inmediata"`, `"verifica tu identidad"`, `"último aviso"`, `"actualiza tus datos ahora"`, `"haz clic"`, `"evita el bloqueo"`, `"ingresa aquí"`).
- **Acción:**
  - `classification: "sospechosa"`
  - `moneo_type: null`
  - `create_transaction: false` (**PROHIBIDO** invocar `TransactionService.processTransaction()` o crear `Add_data`).
  - `decision_source: "anti_fraud"`
  - `requires_review: true`

### Etapa 1 — Aprendizaje Local (`Hive` box `"learned_patterns"`)
- Consulta la caja local cifrada/persistida `"learned_patterns"` usando el `comercio` normalizado (minúsculas, sin tildes ni sufijos numéricos de sucursal).
- Si existe un patrón confirmado por el usuario con suficiente respaldo (`confirmations >= 1` y sin conflicto reciente):
  - Asigna `classification`, `category`, `account_name` (y `destination_account` si aplica).
  - `decision_source: "learned_patterns"`
  - Eleva `confidence` según historial de confirmaciones.
  - **No** invoques a Gemma.

### Etapa 2 — Reglas Deterministas (Sin LLM)
- **Transferencia propia (`transferencia-propia` → `'Transfer'`):**
  - Se detecta cuenta origen **y** cuenta destino pertenecientes a las cuentas locales del usuario (`SharedPreferences('accounts')` / `AccountItem` por alias o últimos 4 dígitos), **o**
  - Existe un par débito/crédito por el mismo monto en una ventana corta entre dos cuentas propias distintas.
- **Ingreso (`ingreso` → `'Income'`):**
  - Verbos/palabras clave de abono (`recibiste`, `abono`, `nómina`, `depósito`, `reembolso`, `rendimientos`) sin indicios de transferencia entre cuentas propias.
- **Gasto (`gasto` → `'Expenses'`):**
  - Verbos/palabras clave de consumo (`compra`, `pago`, `débito`, `retiro`, `suscripción`, `cargo`) + reglas de palabras clave para categoría propuesta (supermercado, transporte, servicios, salud, etc.).
- Si la regla determinista es unívoca (`confidence >= 0.80`), `decision_source: "deterministic_rules"` y **no** invoques a Gemma.

### Etapa 3 — Respaldo On-Device con Gemma (`flutter_gemma`)
- **Cuándo usar:** **ÚNICAMENTE** cuando las etapas 1 y 2 dejan `classification` ambiguo o `confidence < 0.80`.
- **Restricción de hardware (`PROJECT_AUDIT.md`):** `gemma-4-E2B-it.litertlm` pesa ~2.58 GB y requiere >= 4 GB de RAM; en gama media/baja puede no estar cargado.
  - Si Gemma está disponible: envía solo un prompt compacto (sin datos sensibles innecesarios) pidiendo JSON `{classification, category, confidence}`.
  - Si Gemma no está disponible o falla: conserva la mejor hipótesis determinista con `requires_review: true` y `decision_source: "fallback_ambiguous"` para que `moneo-feedback-loop` la resuelva manualmente.

---

## Contrato de Salida y Archivos Protegidos

```json
{
  "classification": "gasto | ingreso | transferencia-propia | sospechosa",
  "moneo_type": "Expenses | Income | Transfer | null",
  "category": "Alimentación",
  "account_name": "Cuenta Ahorros *4821",
  "destination_account": null,
  "confidence": 0.91,
  "requires_review": false,
  "create_transaction": true,
  "decision_source": "anti_fraud | learned_patterns | deterministic_rules | gemma_fallback | fallback_ambiguous"
}
```

> **Archivos protegidos (`AGENTS.md`):** No modifiques `lib/data/transaction_service.dart`, `lib/data/credit_card_calculator.dart` ni `lib/data/model/*.g.dart` sin aprobación explícita del usuario. El clasificador es un servicio puro desacoplado que entrega la propuesta a `moneo-feedback-loop`.

## Verificación Determinista

Ejecuta el validador de invariantes antes de dar por buena la lógica de clasificación:

```bash
uv run .agents/skills/moneo-transaction-classifier/scripts/validate_classification.py --self-test
uv run .agents/skills/moneo-transaction-classifier/scripts/validate_classification.py ruta/a/clasificacion.json
```
