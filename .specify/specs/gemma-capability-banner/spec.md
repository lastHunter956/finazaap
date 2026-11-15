# Spec: Banner de Capacidad de Dispositivo para Gemma IA (`gemma-capability-banner`)

> **Rama objetivo:** `agent/ai/capability-banner-fix`
> **Archivos alcanzados (implementación):** `lib/Screens/ai_chat_screen.dart`, `lib/services/ai_chat_service.dart`, pruebas en `test/audit/t2_2_gemma_ui_and_capability_test.dart` (o suite complementaria).
> **Archivos protegidos afectados:** **Ninguno.** No se modifican `transaction_service.dart`, `credit_card_calculator.dart`, `*.g.dart`, `build.gradle`, `AndroidManifest.xml` ni `lib/core/security/*`.

---

## 1. Objetivo y Problema

`DeviceCapabilityResult.canRunModel` (`lib/services/device_capability_service.dart`) evalúa **4 condiciones**:
1. `hasEnoughStorage` (`freeStorageGB >= 3.5`)
2. `hasEnoughRAM` (`totalRAMGB == null || totalRAMGB! >= 4.0`)
3. `hasEnoughAvailableRAM` (`!lowMemory && (availRAMGB == null || availRAMGB! >= 2.0)`)
4. `hasCompatProcessor` (`isArm64`)

Actualmente:
- `_buildIncompatibilityBanner` (`lib/Screens/ai_chat_screen.dart`) solo renderiza 3 filas `_specRow` (`Almacenamiento libre`, `RAM total`, `Procesador`), omitiendo `hasEnoughAvailableRAM`. Cuando falla únicamente la RAM disponible, el banner muestra las 3 filas en verde junto al título `"Tu dispositivo no tiene los recursos suficientes"`, generando contradicción visual.
- No se distingue entre **insuficiencia transitoria de RAM disponible** (hardware mínimo cumplido, pero presión de memoria actual) e **incompatibilidad de hardware** permanente.
- El mensaje de excepción `INCOMPATIBLE` en `AiChatService._tryLoadGemmaModel` (`lib/services/ai_chat_service.dart`) omite `availRAMGB` y `lowMemory`, y `_deviceCapability` no se refresca de forma limpia al reintentar verificación o configurar una URL (`setModelUrl`).

---

## 2. Requerimientos Funcionales y Criterios de Aceptación

### R1. Mostrar la 4.ª condición (`hasEnoughAvailableRAM`) en `_buildIncompatibilityBanner`
- Agregar una cuarta llamada a `_specRow` en `lib/Screens/ai_chat_screen.dart` dentro de `_buildIncompatibilityBanner(DeviceCapabilityResult cap)`:
  - Etiqueta: `'RAM disponible'`
  - Valor mostrado:
    - Si `cap.availRAMGB != null` y `!cap.lowMemory`: `'${cap.availRAMGB!.toStringAsFixed(1)} GB'`
    - Si `cap.availRAMGB != null` y `cap.lowMemory`: `'${cap.availRAMGB!.toStringAsFixed(1)} GB (baja memoria)'`
    - Si `cap.availRAMGB == null`: `cap.lowMemory ? 'baja memoria' : 'desconocida'`
  - Estado `ok`: `cap.hasEnoughAvailableRAM`
  - Requisito `req`: `'≥ 2.0 GB'`
- Mantener exactamente el estilo y contrato de `_specRow(String label, String value, bool ok, String req)`.

### R2. Diferenciar insuficiencia transitoria de RAM vs. incompatibilidad de hardware
- Definir insuficiencia transitoria como:
  `isTransientLowMemory = cap.hasEnoughStorage && cap.hasEnoughRAM && cap.hasCompatProcessor && !cap.hasEnoughAvailableRAM`
- **Caso `isTransientLowMemory == true`:**
  - Título del banner: `'RAM disponible insuficiente en este momento'` (en lugar de `'Tu dispositivo no tiene los recursos suficientes'`).
  - Mensaje explicativo claro indicando que el hardware cumple el mínimo pero actualmente hay poca RAM libre (sugerir cerrar otras aplicaciones en segundo plano y reintentar).
  - Botón de acción `"Reintentar verificación"` (habilitado cuando `!_chatService.checkingDeviceSpecs`) que re-ejecute `DeviceCapabilityService.check()` mediante `AiChatService` **sin disparar descarga automática** (`allowDownload: false`).
  - En `_buildModelUrlSetup()`, ajustar el subtítulo cuando `isTransientLowMemory` para no sugerir falsamente que el hardware requiere un modelo más ligero como única salida, conservando el campo de URL manual operativo.
- **Caso incompatibilidad de hardware (`!isTransientLowMemory`):**
  - Mantener el título `'Tu dispositivo no tiene los recursos suficientes'` y el mensaje `'Aun así, puedes intentarlo ingresando la URL de un modelo más ligero abajo.'` junto con el botón `"Reintentar verificación"` opcional o solo en el banner (si se incluye en ambos o solo en transitorio, debe re-ejecutar `DeviceCapabilityService.check()` sin descarga automática).

### R3. Diagnóstico `INCOMPATIBLE` y refresco limpio de `_deviceCapability`
- En `AiChatService._tryLoadGemmaModel` (`lib/services/ai_chat_service.dart`):
  - Incluir `availRAMGB` y `lowMemory` en el mensaje de excepción `INCOMPATIBLE`:
    `'INCOMPATIBLE: RAM ${cap.totalRAMGB?.toStringAsFixed(1) ?? "?"} GB | RAM libre ${cap.availRAMGB?.toStringAsFixed(1) ?? "?"} GB (lowMemory: ${cap.lowMemory}) | Espacio ${cap.freeStorageGB.toStringAsFixed(1)} GB | ARM64: ${cap.isArm64}'`
- Exponer en `AiChatService` un método público (p. ej. `Future<DeviceCapabilityResult> retryCapabilityCheck()`) que:
  1. Marque `_checkingDeviceSpecs = true` y notifique listeners.
  2. Ejecute `DeviceCapabilityService.check()` y actualice `_deviceCapability = cap`.
  3. Limpie `_gemmaError` si `cap.canRunModel == true` (o actualice `_gemmaError` con el nuevo mensaje `INCOMPATIBLE` si sigue siendo `false`), sin disparar descarga automática (`downloadAttemptCount` y `networkRequestCount` permanecen en `0`).
  4. Si `cap.canRunModel == true` y ya existe un modelo instalado localmente (o se invoca `_tryLoadGemmaModel(allowDownload: false)`), permita activarlo sin descargar de red.
- Al configurar URL mediante `setModelUrl(String url)` / `_tryLoadGemmaModel(customMobileUrl: url, ...)`:
  - Refrescar o limpiar `_deviceCapability` de manera coherente (p. ej. actualizando `_deviceCapability = await DeviceCapabilityService.check()` antes de instalar/cargar o limpiando estado obsoleto si se fuerza una URL personalizada) para evitar mostrar un banner de incompatibilidad desactualizado tras cambiar la URL.

### R4. Preservación de invariantes y compatibilidad con pruebas existentes
- **No autodescarga:** Abrir `AiChatScreen` o ejecutar `"Reintentar verificación"` nunca debe iniciar descarga automática de Gemma (`allowDownload: false`).
- **No regresión de pruebas:** `test/audit/t2_2_gemma_ui_and_capability_test.dart` debe seguir pasando íntegro (incluyendo la preservación de `_modelUrlController` ante `notifyListeners()`).
- **Alcance offline:** Sin dependencias externas ni llamadas de red en la verificación de capacidades.

---

## 3. Estrategia de Verificación y Comandos (Docker)

Todas las validaciones se ejecutan exclusivamente en el contenedor Docker `flutter-env`:
- Análisis estático: `docker-compose exec -T flutter-env dart analyze`
- Pruebas focalizadas: `docker-compose exec -T flutter-env flutter test --no-pub -j 1 test/audit/t2_2_gemma_ui_and_capability_test.dart`
- Suite completa: `docker-compose exec -T flutter-env flutter test --no-pub -j 1`

---

## 4. Criterios de Término (Done)

1. `_buildIncompatibilityBanner` muestra las 4 filas `_specRow`, incluyendo `RAM disponible` (`hasEnoughAvailableRAM`).
2. Cuando solo falla `hasEnoughAvailableRAM`, el banner muestra título/mensaje de insuficiencia transitoria y botón `"Reintentar verificación"` que actualiza `DeviceCapabilityService.check()` sin descarga automática.
3. El mensaje `INCOMPATIBLE` de `AiChatService._tryLoadGemmaModel` incluye `availRAMGB` y `lowMemory`, y `_deviceCapability` se refresca limpiamente al reintentar o configurar URL.
4. Pruebas unitarias y de widget nuevas + `test/audit/t2_2_gemma_ui_and_capability_test.dart` + `dart analyze` + suite completa pasan en Docker.
