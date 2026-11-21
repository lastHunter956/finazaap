# Lecciones Aprendidas (`docs/handoff/LESSONS.md`)

> Errores reales detectados y reglas prácticas para evitar repetirlos.

1. **Directorio de trabajo de los hooks en Antigravity (`hooks.json`):**
   - `command_hook_executor.go` ejecuta los scripts definidos en `.agents/hooks.json` con directorio de trabajo en `.agents/` (no en la raíz del repositorio).
   - Usar rutas relativas fijas (`./hooks/...` o `.agents/hooks/...`) puede fallar según el contexto o los worktrees. Resolver la raíz dinámicamente con `ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)` y ejecutar `"$ROOT/.agents/hooks/<script>"` funciona en el repo principal, dentro de `.agents/` y en cualquier `git worktree`.

2. **Restricciones del sandbox en `settings.json` (`permissions`):**
   - El sandbox Seatbelt de macOS en `agy` rechaza reglas `write_file(...)` con rutas relativas o globs (`sandbox configuration error: deny .env: non-absolute file path`, `globs not supported`), bloqueando cualquier `run_command`.
   - Por ello, `settings.json` del perfil conserva únicamente reglas `command(...)`, mientras que el bloqueo de rutas relativas, globs, `.env`, secretos y `.git/` en cualquier repo o worktree vive en `.agents/hooks/security_guard.py`.

3. **Los guardianes `PreToolUse` deben ser *fail-closed*:**
   - Un hook que devuelve `{"decision": "allow"}` cuando el payload JSON falla o falta un campo convierte cualquier cambio de esquema en una omisión silenciosa de seguridad.
   - Ante JSON inválido, `toolCall` ausente o `args` sin ruta/`CommandLine`, `security_guard.py` y `check_protected_files.py` devuelven `deny`.

4. **Evitar colisiones de `Stop` cuando hay tareas en segundo plano (`fullyIdle`):**
   - Si el agente cierra un turno esperando una tarea en segundo plano (`fullyIdle: false`), ejecutar `flutter test` en `pre_stop_test.sh` colisiona con otros comandos concurrentes en el mismo contenedor Docker.
   - `pre_stop_test.sh` verifica `fullyIdle`, `continuationActive` y `terminationReason` antes de correr `docker-compose exec -T flutter-env flutter test -j 1`, y verifica con `docker-compose ps -q flutter-env` que el servicio esté activo (nunca declara éxito silencioso si no corrió pruebas).

5. **Ejecución de pruebas Flutter en Docker (`-j 1` y `-T`):**
   - `flutter test` sin `-j 1` dentro del contenedor puede agotar memoria (OOM, código `137`).

6. **Zsh y variable `PATH`:**
   - En `zsh`, usar `for path in ...` sobrescribe la variable especial `$PATH` (enlazada a `$path`) y rompe la resolución de `python3`, `docker-compose` y utilidades del sistema. Usar siempre otro nombre de variable (`fpath`, `item`, etc.).

7. **Widget tests con `Hive` bajo `FakeAsync`:**
   - Según `docs/discovery/SPRINT_1_REPORT.md`, las pruebas `testWidgets` pueden sufrir timeout si ejecutan E/S real de `Hive` en disco dentro de `FakeAsync`; usar mocks/cajas en memoria en widget tests y dejar `Hive` en disco para tests unitarios y de integración.

8. **Caché incremental obsoleto de Gradle en `mergeProdReleaseNativeLibs` (Docker bind-mount):**
   - Al recompilar un APK release tras cambios en Dart sobre el bind-mount de macOS en Docker, `compileFlutterBuildProdRelease` puede generar un `libapp.so` nuevo en `build/app/intermediates/flutter/prodRelease/jniLibs/`, pero `mergeProdReleaseNativeLibs` puede marcarse `UP-TO-DATE` y empaquetar un `libapp.so` viejo dentro del APK.
   - Verificar siempre el SHA-256 de `lib/arm64-v8a/libapp.so` extraído del APK final (`unzip -p ... | sha256sum`); si coincide con el build anterior, ejecutar `flutter clean` antes de `flutter build apk --release --flavor prod --no-tree-shake-icons --android-skip-build-dependency-validation`.
