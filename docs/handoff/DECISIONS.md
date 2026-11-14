# Decisiones Aprobadas (`docs/handoff/DECISIONS.md`)

> Solo decisiones verificadas y aprobadas. No registrar datos financieros reales ni secretos.

## 1. Entorno de Compilación y Pruebas
- **Flutter/Dart exclusivamente en Docker:** Toda ejecución de `dart analyze`, `dart format`, `flutter test -j 1`, `flutter pub get` y `build_runner` se realiza mediante el servicio `flutter-env` (`docker-compose exec -T flutter-env ...`). No se instalan SDKs ni herramientas adicionales en el host macOS.

## 2. Arquitectura de Seguridad y Restricciones en Doble Capa
- **Capa principal (portable en el repositorio):** `.agents/hooks.json` y los scripts ejecutables en `.agents/hooks/` (`security_guard.py`, `check_protected_files.py`, `session_start_handoff.sh`, `post_edit_analyze.sh`, `pre_stop_test.sh`), con comportamiento **fail-closed** (`deny` ante JSON/argumentos inválidos).
- **Capa secundaria (perfil local del usuario):** bloque `"permissions"` en `/Users/jesusmartinez/.agys/profiles/karoll/.gemini/antigravity-cli/settings.json` (reglas `deny` / `ask` / `allow`).
- **Política de red:** No se bloquean globalmente `curl`/`wget`/`nc`/`scp`/`rsync`; se deniega la exfiltración de secretos, notificaciones o datos financieros y se pide `force_ask` cuando una petición de red mencione términos/rutas sensibles.
- **Política de teléfono/ADB:** `deny` estricto para `adb uninstall`, `pm clear`, `am force-stop`, `adb install -d` (downgrade) y borrado de datos; `force_ask` para `adb install` / `flutter install` exigiendo mostrar antes commit, ruta y SHA-256 del APK, dispositivo, `applicationId`, `versionCode`, `versionName`, firma/certificado y confirmación de preservación de datos.

## 3. Flujo de Desarrollo, Git y Archivos Protegidos
- **Flujo obligatorio:** `spec` → `plan` → `tasks` → `implement` → `test` (ver `.agents/rules/flujo-desarrollo.md`).
- **Ramas Git:** Prohibido hacer commits o merges directos en `main`. El trabajo de agentes vive en ramas `agent/<nombre>/<tarea>` (con `git worktree` en paralelo). `git push`, `git merge` y `git rebase` requieren `force_ask`.
- **Archivos protegidos:** `lib/data/transaction_service.dart`, `lib/data/credit_card_calculator.dart`, `lib/data/model/*.g.dart`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml` y `lib/core/security/*` requieren aprobación explícita del usuario.

## 4. Privacidad y Anti-Fraude en Notificaciones
- No leer ni persistir notificaciones de apps no seleccionadas por el usuario.
- No enviar datos financieros ni contenido íntegro de notificaciones reales a servicios externos ni incluirlos en fixtures, logs, handoff o commits.
- Nunca seguir, abrir ni resolver URLs recibidas en notificaciones, ni tratar una URL por sí sola como evidencia de fraude.
