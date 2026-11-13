---
name: moneo-feedback-loop
description: >-
  Gestiona el ciclo de confirmación, corrección y descarte de transacciones
  detectadas en Moneo mediante la bandeja de "transacciones pendientes", el modo
  "aceptar todo" (solo alta confianza) y la actualización de la tabla Hive
  "learned_patterns". Usar al diseñar o probar la UI de revisión y el feedback.
---

# Moneo Feedback Loop

Skill de dominio para cerrar el ciclo de aprendizaje continuo en Moneo: las notificaciones clasificadas no alteran los saldos reales hasta que el usuario las confirma o corrige en la bandeja de **transacciones pendientes**.

## Skills genéricas que debes reutilizar (NO duplicar)

- **`frontend-ui-engineering`**: Construye la bandeja accesible, responsiva y consistente con el tema oscuro de Moneo.
- **`flutter-add-widget-test`** y **`test-driven-development`**: Escribe widget tests que fallen si `"aceptar todo"` acepta elementos de baja confianza/sospechosos o si no se actualiza `learned_patterns`.

---

## Reglas de UI y Diseño (Dominio Moneo)

- **Colores:** Usa exclusivamente `AppColors` (`lib/themes/app_colors.dart`, fondo `0xFF1F2639`, acento `0xFF52E2FF`). **Prohibido** hardcodear colores inline.
- **Formato de moneda:** Usa `CurrencyHelper` (`lib/utils/currency_helper.dart`) para mostrar el monto según la divisa configurada (COP, USD, MXN, etc.).
- **Elemento mínimo de cada tarjeta pendiente:**
  - Descripción / comercio detectado (`comercio` o resumen sanitizado).
  - Categoría propuesta (`category`) + tipo (`gasto` / `ingreso` / `transferencia-propia`) + insignia visual si es `"sospechosa"` o de baja confianza (`requires_review == true`).
  - Monto formateado con `CurrencyHelper`.
  - Botones explícitos: **Confirmar**, **Corregir** (abre selector de tipo/categoría/cuenta) y **Descartar**.

---

## Reglas de Negocio e Invariantes

### 1. Aislamiento de Saldos Reales
- Mientras un ítem esté en la bandeja de pendientes, **NO** debe existir en la caja Hive `'data'` ni modificar `SharedPreferences('accounts')`.
- Solo al **Confirmar** o **Corregir** un ítem válido (nunca `"sospechosa"` directamente sin reclasificación explícita del usuario) se invoca `TransactionService.processTransaction(..., recordInHive: true)`.
- **Descartar** elimina el ítem de pendientes sin tocar saldos ni `learned_patterns`.

### 2. Modo `"Aceptar todo"` (Filtro Estricto de Alta Confianza)
- El botón global **"Aceptar todo"** solo procesa en lote los ítems que cumplan **todas** estas condiciones:
  1. `classification != "sospechosa"`
  2. `requires_review == false`
  3. `confidence >= 0.85` (umbral de alta confianza para aceptación en lote)
  4. `account_name != null` (y `destination_account != null` si es transferencia propia)
- Los ítems de **baja confianza**, ambiguos o marcados como `"sospechosa"` **permanecen en la bandeja** para revisión manual.
- La UI debe mostrar claramente cuántos ítems se aceptaron y cuántos quedaron pendientes por revisión manual.

### 3. Actualización de `learned_patterns` (Hive Box `"learned_patterns"`)
- Al **Confirmar**:
  - Incrementa `confirmations` para la clave `comercio_normalizado` en la caja `"learned_patterns"` manteniendo `category`, `classification` y `account_name` (y `destination_account` si aplica).
- Al **Corregir**:
  - Sobrescribe el mapeo `comercio_normalizado → {classification, category, account_name, destination_account}` con la elección del usuario, reinicia o pondera `confirmations = 1` y registra `last_corrected_at` para que las futuras clasificaciones usen la corrección inmediatamente.

---

## Verificación Determinista y Tests

1. **Valida los invariantes del lote y de `learned_patterns`:**
   ```bash
   uv run .agents/skills/moneo-feedback-loop/scripts/verify_feedback_invariants.py --self-test
   ```
2. **Widget tests obligatorios (`flutter-add-widget-test`):**
   - Renderiza bandeja mixta (2 alta confianza, 1 baja confianza, 1 `"sospechosa"`).
   - Pulsa **"Aceptar todo"** → verifica que solo se confirman los 2 de alta confianza, los otros 2 permanecen visibles en la bandeja, y `learned_patterns` se actualizó exactamente 2 veces.
   - Pulsa **Corregir** en el ítem de baja confianza → verifica que `learned_patterns` guarda la nueva categoría/cuenta.
   - Pulsa **Descartar** → verifica que no llama a `TransactionService.processTransaction()` ni altera `learned_patterns`.
