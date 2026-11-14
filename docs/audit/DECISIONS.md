# Decisiones Humanas Obligatorias (`docs/audit/DECISIONS.md`)

> Ningún modelo (ligero o fuerte) debe tomar estas decisiones por su cuenta. El usuario debe responderlas antes de ejecutar las tareas que dependen de cada una.

---

### D1. Modelo de IA: Descarga por red vs. Archivo local 100% offline
- **Opciones:**
  - **A (Recomendada):** Cambiar modelo por defecto a uno liviano (~500–800 MB, ej. Gemma 3 1B int4) **Y** permitir cargar un `.litertlm` / `.task` local desde el teléfono (`file_picker` + `fromFile`) para uso 100% offline sin descarga.
  - **B:** Mantener `gemma-4-E2B-it` (2.59 GB) descargado solo bajo demanda con barra de progreso.
  - **C:** Desactivar Gemma en móvil y usar solo el simulador por reglas.
- **Riesgos:** En B, teléfonos de 4–6 GB RAM seguirán sufriendo OOM/LMKD o caída a CPU lenta.
- **Qué se rompe si se elige mal:** Si se empaqueta el binario de 2.59 GB dentro del APK, el APK superará ~2.9 GB y fallará en la mayoría de instalaciones/tiendas.

### D2. Permiso `INTERNET` en `AndroidManifest.xml` (Release)
- **Opciones:**
  - **A (Recomendada si D1 usa descarga):** Añadir `<uses-permission android:name="android.permission.INTERNET"/>` en `android/app/src/main/AndroidManifest.xml` (archivo protegido) y desactivar `GoogleFonts.config.allowRuntimeFetching = false`.
  - **B (Máxima privacidad offline):** NO añadir `INTERNET`; en release el modelo solo podrá cargarse desde archivo local (D1 opción A sin descarga).
- **Riesgos:** Sin `INTERNET`, cualquier descarga desde HuggingFace en APK release falla inmediatamente.
- **Qué se rompe si se elige mal:** Elegir "descarga automática" sin `INTERNET` deja el botón de descarga roto en release; añadir `INTERNET` sin `allowRuntimeFetching = false` filtra peticiones a `fonts.gstatic.com`.

### D3. Cambio de `applicationId` (`com.example.finazaap` → ID propio)
- **Opciones:**
  - **A (Antes de distribución externa):** Cambiar `applicationId` y `namespace` a un ID propio (ej. `com.moneo.app`) junto con backup/export previo en el teléfono.
  - **B (Durante pruebas locales actuales):** Mantener `com.example.finazaap` temporalmente para conservar los datos instalados hoy en `R5CY21GE9YY`.
- **Riesgos:** Cambiar `applicationId` instala una app **distinta** en Android; los datos actuales en `com.example.finazaap` NO se transfieren automáticamente.
- **Qué se rompe si se elige mal:** Si cambias `applicationId` sin exportar datos antes, parecerá que perdiste tus cuentas y transacciones en el teléfono.

### D4. Firma de compilación `release` (`signingConfigs.release`)
- **Opciones:**
  - **A (Recomendada):** Generar un `keystore` propio fuera de Git + `key.properties` (ignorado en `.gitignore`) y configurarlo en `android/app/build.gradle`.
  - **B:** Seguir solo con `apk-debug` para pruebas locales.
- **Riesgos:** Publicar un APK release firmado con `signingConfigs.debug` permite que cualquiera suplante actualizaciones con la clave pública debug.
- **Qué se rompe si se elige mal:** Si pierdes el `keystore` release después de instalar, no podrás actualizar la app sin desinstalar y perder datos locales.

### D5. Cifrado en reposo (`Hive`, `SharedPreferences`, `moneo_notif_queue.json`) y `EncryptionService`
- **Opciones:**
  - **A (Recomendada):** Activar `HiveAesCipher` en `data` y `responsibilities` (reutilizando el patrón de `NotificationBoxEncryption` con migración segura), migrar cuentas/saldos/historial IA fuera de `SharedPreferences` en claro (o cifrarlos con `AES-GCM` + IV aleatorio en `EncryptionService`), y cifrar `moneo_notif_queue.json` en Kotlin con `EncryptedFile` / Android Keystore.
  - **B:** Cifrar solo notificaciones y dejar `data`/`accounts` en claro (NO recomendado: contradice la política de privacidad de la app).
- **Riesgos:** Una migración mal probada en cajas Hive existentes puede bloquear la lectura de datos previos.
- **Qué se rompe si se elige mal:** Dejar `EncryptionService` con IV fijo y fallback Base64 mantiene falsa sensación de seguridad; migrar sin respaldo ni prueba de compatibilidad puede corromper datos reales.

### D6. Política de PIN, intentos fallidos y re-bloqueo en segundo plano
- **Opciones:**
  - **A (Recomendada):** Hashear PIN con `PBKDF2-HMAC-SHA256` + salt aleatorio en `FlutterSecureStorage`, mover `pin_enabled` a `FlutterSecureStorage`, bloqueo exponencial tras 5 fallos (30 s, 60 s...), re-pedir PIN al volver de segundo plano (>15 s o inmediato), `FLAG_SECURE` activo cuando PIN esté habilitado.
  - **B:** Igual pero sin `FLAG_SECURE` (permite capturas de pantalla).
- **Riesgos:** Usuarios con PIN ya guardado en claro en `FlutterSecureStorage` necesitan migración automática al primer login exitoso (leer PIN legado -> verificar -> re-guardar hasheado).
- **Qué se rompe si se elige mal:** Si cambias `verifyPin` a hash sin migrar el PIN legado, los usuarios con PIN activo quedarían bloqueados fuera de su app.

### D7. Backups (`allowBackup` de Android vs Exportación JSON de la app)
- **Opciones:**
  - **A (Recomendada):** Poner `android:allowBackup="false"` en `AndroidManifest.xml` y añadir cifrado opcional con contraseña (o advertencia clara) en `DataManagementService.exportAndShareData()`, limpiando archivos temporales `moneo_backup_*.json` tras compartir.
- **Qué se rompe si se elige mal:** `allowBackup="true"` permite extraer bases en claro por ADB/backup D2D.

### D8. Reparación de saldos existentes tras corregir los bugs de Ola 1
- **Opciones:**
  - **A (Recomendada):** Al desplegar Ola 1, NO ejecutar recálculos automáticos silenciosos sobre saldos históricos existentes en tu teléfono. Incluir una herramienta explícita bajo confirmación humana (o ajuste manual por cuenta) tras revisar el reporte de `T0.1`.
  - **B:** Recalcular automáticamente `cardBalance` y `available_balance` desde el historial.
- **Riesgos:** Como los bugs de doble deuda y borrado sin reversión ya afectaron datos reales previos, un recálculo automático sin inspección puede cambiar un saldo que el usuario ya ajustó a mano.
- **Qué se rompe si se elige mal:** Cualquier migración automática no autorizada puede alterar tus saldos reales sin trazabilidad.
