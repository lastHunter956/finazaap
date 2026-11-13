---
name: moneo-notification-parser
description: >-
  Parsea notificaciones bancarias de Android en Moneo a una estructura JSON
  tipada {tipo, monto, comercio, fecha, cuenta} usando patrones genéricos y
  validación cruzada (sin plantillas fijas por banco), con detección anti-fraude
  de links y campos confidence y requires_review. Usar al diseñar, implementar
  o probar la extracción de movimientos desde texto crudo de notificaciones.
---

# Moneo Notification Parser

Skill de dominio para convertir notificaciones bancarias crudas (Android `NotificationListenerService` / bandeja offline) en eventos financieros estructurados, tipados y seguros para Moneo (`finazaap`).

> **Contexto del proyecto:** Moneo es 100% offline. Según `docs/discovery/PROJECT_AUDIT.md`, actualmente solo existe un regex básico en `AiChatService` y no hay `NotificationListenerService`. Ningún texto crudo de notificación puede salir del dispositivo ni registrarse con `print()`.

## Skills genéricas que debes reutilizar (NO duplicar)

- **`dart-use-pattern-matching`**: Implementa la deserialización, validación de esquema JSON y ramificación por estado (`ParsedNotification` como `sealed class` / `switch` exhaustivo).
- **`dart-add-unit-test`** y **`test-driven-development`**: Escribe pruebas unitarias en `test/` que puedan fallar ante errores reales de parsing (nunca tests triviales).
- **`security-and-hardening`**: Verifica privacidad offline y sanitización de entradas.

---

## Reglas obligatorias de extracción

### 1. Prohibido confiar en plantillas fijas por banco
- **NO** codifiques reglas rígidas del tipo `if (package == 'com.bancolombia') ...`. Los bancos cambian el copy con frecuencia y existen decenas de entidades/billeteras.
- Usa **extracción por patrones genéricos** combinada con **validación cruzada**:
  - **Monto (`monto`):** Detecta símbolos (`$`, `COP`, `USD`, `MXN`, `S/`, `£`, `EUR`) y ambos formatos de `CurrencyHelper` (`lib/utils/currency_helper.dart`):
    - Formato Latino/Europeo (COP/ARS): `.` para miles y `,` para decimales (ej. `$ 1.250.000,50` o `$45.000`).
    - Formato Americano (USD/MXN/PEN/GBP): `,` para miles y `.` para decimales (ej. `$1,234.56`).
    - **Validación cruzada:** Si un separador tiene exactamente 3 dígitos detrás y no hay otro separador decimal (ej. `$45.000` en contexto COP), no lo interpretes como `45.0`. Si existe ambigüedad entre miles y decimales (ej. `1.234` sin moneda clara), reduce `confidence` y activa `requires_review: true`.
  - **Tipo preliminar (`tipo`):** Palabras clave genéricas de débito/compra/retiro (`compra`, `pago`, `débito`, `retiro`, `transferiste`, `enviaste`, `cargo`) vs abono/ingreso (`recibiste`, `abono`, `depósito`, `consignación`, `transferencia recibida`) vs transferencia (`transferencia entre cuentas`, `mismo titular`). Si hay señales contradictorias o ausentes, `tipo: "desconocido"` y `requires_review: true`.
  - **Comercio (`comercio`):** Extrae el token posterior a conectores genéricos (`en `, `a `, `comercio `, `establecimiento `, `de `) limpiando sufijos de tarjeta/hora; si no se identifica, devuelve `null` y baja `confidence`.
  - **Fecha (`fecha`):** Normaliza fechas explícitas en el texto (ISO-8601) o usa el timestamp de recepción del sistema (`postTime` de `StatusBarNotification`) indicando en metadatos si fue inferida.
  - **Cuenta (`cuenta`):** Extrae últimos 4 dígitos (`*1234`, `XXXX1234`, `terminada en 1234`) o alias/tipo (`ahorros`, `corriente`, `TC`, `tarjeta de crédito`, `billetera`) para cruzar contra `AccountItem` / `SharedPreferences('accounts')`.

### 2. Regla Anti-Fraude (Bloqueo estricto por links)
- Los bancos reales rara vez solicitan hacer clic en enlaces dentro de una notificación transaccional.
- **Detección obligatoria:** Antes de extraer o aceptar montos, escanea el texto (título + cuerpo) buscando cualquier URL, dominio acortado o esquema sospechoso:
  - `http://`, `https://`, `www.`
  - Acortadores y TLDs frecuentes en phishing (`bit.ly`, `tinyurl.com`, `t.co`, `cutt.ly`, `rb.gy`, `.xyz`, `.top`, `.click`, `wa.me/`, enlaces con parámetros de redirección).
- **Acción obligatoria si contiene link:**
  - Marca el resultado con `"status": "sospechosa"` (y `"tipo": "sospechosa"`).
  - `"confidence": 0.0`
  - `"requires_review": true`
  - `"auto_processable": false` (prohibido procesar automáticamente o crear transacción).

### 3. Contrato de Salida (JSON Tipado)

Todo resultado del parser debe cumplir exactamente este esquema:

```json
{
  "status": "parsed | sospechosa | unparseable",
  "tipo": "gasto | ingreso | transferencia | desconocido | sospechosa",
  "monto": 45000.0,
  "moneda": "COP",
  "comercio": "Éxito Laureles",
  "fecha": "2026-11-13T14:30:00-05:00",
  "cuenta": {
    "last4": "4821",
    "hint": "tarjeta de crédito"
  },
  "confidence": 0.92,
  "requires_review": false,
  "auto_processable": true,
  "flags": []
}
```

**Invariantes no negociables:**
1. Si `status == "sospechosa"`, entonces `tipo == "sospechosa"`, `auto_processable == false`, `requires_review == true` y `confidence == 0.0`.
2. Si `monto == null` o `monto <= 0`, entonces `requires_review == true` y `auto_processable == false`.
3. Si `confidence < 0.80`, entonces `requires_review == true`.
4. Si `requires_review == true`, entonces `auto_processable == false`.

---

## Flujo de Trabajo y Verificación

1. **Diseña el modelo en Dart** usando `dart-use-pattern-matching` (`sealed class NotificationParseResult` con casos `ParsedTransaction`, `SuspiciousNotification`, `UnparseableNotification`).
2. **Valida el contrato JSON** ejecutando el script determinista incluido en esta skill:
   ```bash
   uv run .agents/skills/moneo-notification-parser/scripts/validate_parser_output.py --self-test
   ```
   O pasando un archivo JSON generado por tu parser:
   ```bash
   uv run .agents/skills/moneo-notification-parser/scripts/validate_parser_output.py ruta/a/salida.json
   ```
3. **Escribe tests unitarios que puedan fallar** usando `dart-add-unit-test`:
   - Casos positivos multi-formato: monto COP (`$ 120.000`), monto USD (`$1,234.56`), sin comercio explícito, con últimos 4 dígitos.
   - Casos negativos obligatorios: notificación con `https://...` o `bit.ly/...` (debe marcar `"sospechosa"` y `auto_processable: false`), monto ambiguo (`$1.234` sin moneda -> `requires_review: true`), texto no financiero (`"Tu código OTP es 482910"` -> `unparseable` / nunca crear monto `482910`).
   - Ejecuta en Docker (`docker-compose exec flutter-env flutter test`).
