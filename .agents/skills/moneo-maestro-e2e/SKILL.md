---
name: moneo-maestro-e2e
description: Guía de ejecución segura, diseño y análisis de pruebas E2E en Moneo Validación usando Maestro en Docker.
---

# Maestro E2E — Guía Agéntica en Moneo (`finazaap`)

Esta skill rige la ejecución, diagnóstico y diseño de flujos de prueba End-to-End (E2E) mediante Maestro sobre la aplicación Moneo (`com.example.finazaap.validation`) en el dispositivo físico de pruebas.

---

## 1. Cuándo Usar Esta Skill y Recuperación

- **Cuándo usarla:**
  - Validación de flujos críticos tras cambios en lógica de saldos, transacciones, responsabilidades o divisas.
  - Verificación funcional de interfaces Flutter antes de solicitar validación manual humana.
  - Reproducción controlada de regresiones en dispositivo físico.
- **Recuperación tras interrupción:**
  - Si un flujo se corta o falla a mitad de camino, **NO** borres datos (`pm clear` o `clearState` están denegados).
  - Inspecciona el lock de dispositivo en `.maestro-env/device_R5CY21GE9YY.lock`. Si quedó huérfano de un proceso muerto, el lanzador lo limpiará de forma segura.
  - Relanza la app con `stopApp` y `launchApp` sin `clearState` (ver sección 4) para resetear el árbol de widgets a Home.

---

## 2. Verificación Previa Obligatoria

Antes de ejecutar cualquier flujo, confirma:

1. **Dispositivo físico único autorizado:** `R5CY21GE9YY`.
   ```bash
   adb devices | grep "R5CY21GE9YY"
   ```
2. **Variante de aplicación única autorizada:** `com.example.finazaap.validation` (`Moneo Validación`).
   > [!IMPORTANT]
   > La aplicación original `com.example.finazaap` contiene datos reales y está estrictamente protegida. Ningún flujo ni comando puede interactuar con ella.
3. **Estado inicial libre:** Verifica que no haya otra automatización corriendo contra el dispositivo (`.maestro-env/device_R5CY21GE9YY.lock`).

---

## 3. Ejecución de Flujos Existentes

**REGLA:** Ejecuta y audita siempre los flujos ya existentes en `.maestro/` antes de crear nuevos:

```bash
# Ejecución segura mediante lanzador con aislamiento de red
./.maestro/docker/run_maestro.sh test .maestro/audit_01_smoke_persistence.yaml
```

### Suite de flujos auditados disponibles:
- `audit_01_smoke_persistence.yaml`: Creación de cuenta, ingreso, gasto y persistencia tras reinicio.
- `audit_02_transfers_edit_delete.yaml`: Transferencias entre cuentas, edición y borrado de movimientos.
- `audit_02b_delete_and_cc_ui.yaml`: Tarjetas de crédito y exclusión de saldo.
- `audit_03_accounts_and_cc.yaml`: Gestión de cuentas y cupos.
- `audit_04_pagos_reportes_divisas.yaml`: Reportes y visualización multimoneda.
- `audit_05_responsibilities_and_divisas.yaml`: Responsabilidades y selector de divisa base.
- `audit_05b_divisas_and_resp_pay.yaml`: Pagos parciales de responsabilidades.
- `audit_06_resp_pay_and_validation.yaml`: Validación de balances tras liquidación.
- `audit_06b_verify_paid_validation_chat.yaml`: Verificación de estado pagado y chat IA.

---

## 4. Principios de Diseño de Flujos en Moneo

### A. Selectores Semánticos vs Coordenadas
- **Prioridad 1 (Semántico):** Usa `assertVisible: "Texto exacto o Regex"` o `tapOn: "Etiqueta"`.
- **Prioridad 2 (Esperas por estado):** Usa siempre `extendedWaitUntil` en transiciones de pantalla:
  ```yaml
  - extendedWaitUntil:
      visible: "Transacciones"
      timeout: 10000
  ```
- **Prioridad 3 (Coordenadas como último recurso):** Si un widget Flutter no expone Semantics (ej. FAB flotante sin label), documéntalo explícitamente:
  ```yaml
  # Fallback por coordenadas: FAB '+' en Cuentas carece de label semántico
  - tapOn:
      point: "87%,91%"
  ```

### B. Datos Sintéticos y Expectativas Financieras
- Los montos sintéticos deben ser redondos y predecibles (ej. `$ 50.000,00`, `$ 25.000,00`, `$ 15.000,00`).
- Valida la fórmula contable de Moneo:
  $$\text{Disponible} = \sum \text{Cuentas incluidas} - \text{Gastos no liquidados}$$
- Recuerda que las **Tarjetas de Crédito están excluidas de "Disponible"** (el cupo no es dinero propio).

### C. Repetibilidad e Idempotencia
- No asumas que la app está vacía. Comprueba el estado antes de actuar.
- Si un flujo crea una entidad (ej. `CtaPrueba1`), usa nombres sintéticos identificables para no colisionar con datos previos.

### D. Evidencias Locales con Nombres Únicos
- Guarda capturas en `.maestro-env/evidence/` usando timestamp y nombre del paso:
  ```yaml
  - takeScreenshot: /maestro-env/evidence/smoke_post_creacion.png
  ```
- Todos los artefactos permanecen estrictamente locales. Prohibido subir evidencias a servicios externos.

---

## 5. Taxonomía de Resultados y Clasificación de Fallos

Al reportar una ejecución, clasifica cada resultado en una de estas 4 categorías:

| Estado | Significado | Acción |
| :--- | :--- | :--- |
| **`APROBADO` (PASS)** | El flujo completó todas sus aserciones con éxito. | Registrar paso superado. |
| **`DEFECTO DE APLICACIÓN` (APP_DEFECT)** | La app responde pero una aserción financiera o de interfaz falla (ej. saldo calculado incorrecto). | Registrar fallo con captura y esperar validación humana. |
| **`FALLO DE AUTOMATIZACIÓN` (AUTOMATION_DEFECT)** | La app funciona pero el selector cambió, expiró un timeout o falló ADB. | Ajustar el selector semántico o timeout del flujo YAML. |
| **`NO PROBADO` (NOT_TESTED)** | El caso no pudo ejecutarse debido a un bloqueo previo o precondición no cumplida. | Documentar bloqueo y continuar con casos independientes. |

---

## 6. Diferenciación de Tipos de Prueba

- **Prueba Funcional:** Verifica la lógica de negocio, navegación, persistencia de transacciones y cálculo de saldos.
- **Revisión Visual:** Inspecciona desbordamientos tipográficos, recortes de texto (`RenderFlex overflowed`) o contraste.
- **Medición de Rendimiento:** Monitorea tiempos de frame, jank (`GPURasterizer::Draw`, `Animator::BeginFrame`) y comportamiento de overscroll. No mezcles aserciones funcionales con perfiles de rendimiento dentro del mismo flujo.

---

## 7. Alcance, Exclusiones y Límites de Seguridad

- **Exclusión de Ajustes:** En el alcance actual, **únicamente la selección de divisas** está autorizada en Ajustes. Las pantallas de PIN, biometría, cifrado y permisos de notificaciones del sistema están expresamente **excluidas** de automatización para evitar desconfiguración del dispositivo físico.
- **No Confinamiento del SO:** Validar `appId` en el flujo evita invocar otros paquetes desde Maestro, pero no confina el sistema operativo Android completo. Si un flujo abre un diálogo del sistema no controlado, detén la ejecución.
- **Comandos Prohibidos:** Denegados de forma absoluta `clearState: true`, `uninstallApp`, `installApp`, `assertWithAI`, `maestro cloud` y scripts externos no auditados.
