# Tasks: Banner de Capacidad de Dispositivo para Gemma IA (`gemma-capability-banner`)

> **Spec de referencia:** [spec.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/.specify/specs/gemma-capability-banner/spec.md)
> **Archivos protegidos:** Ninguno afectado.

---

## Task 1: Actualizar diagnóstico `INCOMPATIBLE` y refresco de `_deviceCapability` en `AiChatService`

**Descripción:**
Actualizar `AiChatService` para incluir `availRAMGB` y `lowMemory` en el error `INCOMPATIBLE` de `_tryLoadGemmaModel`, agregar el método público `retryCapabilityCheck()` que re-ejecuta `DeviceCapabilityService.check()` sin disparar descargas, y asegurar el refresco limpio de `_deviceCapability` al reintentar o invocar `setModelUrl`.

**Criterios de aceptación:**
- [ ] El mensaje `INCOMPATIBLE` en `_tryLoadGemmaModel` incluye `availRAMGB` (formateado a 1 decimal o `?`) y `lowMemory`.
- [ ] `retryCapabilityCheck()` actualiza `_checkingDeviceSpecs` y `_deviceCapability`, ajusta `_gemmaError` según `cap.canRunModel`, y si `cap.canRunModel == true` delega a `_tryLoadGemmaModel(allowDownload: false)` sin incrementar `downloadAttemptCount` ni `networkRequestCount`.
- [ ] `setModelUrl(String url)` / `_tryLoadGemmaModel(customMobileUrl: ...)` refresca `_deviceCapability` limpiamente para no dejar estado obsoleto en pantalla.

**Verificación:**
- [ ] `docker-compose exec -T flutter-env dart analyze lib/services/ai_chat_service.dart` sin errores.

**Dependencias:** Ninguna.

**Archivos a tocar:**
- `lib/services/ai_chat_service.dart`

**Alcance estimado:** S (1 archivo)

---

## Task 2: Mostrar 4.ª condición y estado transitorio de RAM en `_buildIncompatibilityBanner` (`AiChatScreen`)

**Descripción:**
Actualizar `_buildIncompatibilityBanner` y `_buildModelUrlSetup` en `AiChatScreen` para renderizar la 4.ª fila `_specRow` (`RAM disponible`, `cap.hasEnoughAvailableRAM`, `≥ 2.0 GB`), diferenciar insuficiencia transitoria de RAM disponible frente a incompatibilidad de hardware, y ofrecer el botón `"Reintentar verificación"` conectado a `AiChatService.retryCapabilityCheck()`.

**Criterios de aceptación:**
- [ ] `_buildIncompatibilityBanner` muestra 4 `_specRow`: `Almacenamiento libre`, `RAM total`, `RAM disponible` y `Procesador`.
- [ ] Cuando `hasEnoughStorage && hasEnoughRAM && hasCompatProcessor && !hasEnoughAvailableRAM`, el banner muestra título `'RAM disponible insuficiente en este momento'`, mensaje de recomendación de liberar memoria y botón `"Reintentar verificación"`.
- [ ] Al pulsar `"Reintentar verificación"`, se ejecuta `retryCapabilityCheck()` sin disparar descarga automática del modelo ni perder el texto escrito en `_modelUrlController`.
- [ ] Cuando falla almacenamiento, RAM total o procesador, se mantiene el mensaje de incompatibilidad de hardware.

**Verificación:**
- [ ] `docker-compose exec -T flutter-env dart analyze lib/Screens/ai_chat_screen.dart` sin errores.

**Dependencias:** Task 1.

**Archivos a tocar:**
- `lib/Screens/ai_chat_screen.dart`

**Alcance estimado:** S (1 archivo)

---

## Task 3: Agregar pruebas unitarias/widget y verificar suite completa en Docker

**Descripción:**
Ampliar `test/audit/t2_2_gemma_ui_and_capability_test.dart` (o agregar pruebas en el mismo archivo) para cubrir la 4.ª fila `RAM disponible`, la diferenciación entre insuficiencia transitoria y hardware incompatible, el botón `"Reintentar verificación"` sin descarga automática, y el formato del mensaje `INCOMPATIBLE` con `availRAMGB` y `lowMemory`.

**Criterios de aceptación:**
- [ ] Test unitario verifica que el mensaje `INCOMPATIBLE` incluye `availRAMGB` y `lowMemory` y que `retryCapabilityCheck()` refresca `deviceCapability` con `downloadAttemptCount == 0` y `networkRequestCount == 0`.
- [ ] Widget test verifica las 4 filas `_specRow` (incluyendo `RAM disponible`), el título/mensaje transitorio y el botón `"Reintentar verificación"` cuando solo falla `hasEnoughAvailableRAM`.
- [ ] Widget test verifica el mensaje de incompatibilidad de hardware cuando falla almacenamiento/RAM total/ARM64.
- [ ] El test existente `'preserva texto en _modelUrlController tras notifyListeners()'` sigue pasando sin modificaciones regresivas.

**Verificación:**
- [ ] `docker-compose exec -T flutter-env dart analyze` sin errores.
- [ ] `docker-compose exec -T flutter-env flutter test --no-pub -j 1 test/audit/t2_2_gemma_ui_and_capability_test.dart` pasa al 100%.
- [ ] `docker-compose exec -T flutter-env flutter test --no-pub -j 1` suite completa pasa al 100%.

**Dependencias:** Task 1, Task 2.

**Archivos a tocar:**
- `test/audit/t2_2_gemma_ui_and_capability_test.dart`

**Alcance estimado:** S (1 archivo)

---

## Checkpoint Final
- [ ] `dart analyze` limpio en Docker.
- [ ] `flutter test --no-pub -j 1` completo pasando en Docker.
- [ ] Regla de no autodescarga al abrir Chat preservada (`allowDownload: false`).
