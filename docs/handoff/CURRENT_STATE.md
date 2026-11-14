# Estado Actual del Proyecto (`docs/handoff/CURRENT_STATE.md`)

> **Última actualización:** 2026-11-13 (configuración de arranque automático y restricciones reales validada E2E)  
> **Nota:** Tratar este documento como contexto previo, no como evidencia definitiva. Verificar `git status`, ramas, worktrees y Docker antes de actuar.

---

## 1. Estado Verificado del Repositorio y Entorno

- **Rama actual de configuración:** `agent/config/contexto-y-seguridad` (creada desde `integration/notificaciones-reales` en commit `0ac3c1c`).
- **Commit de configuración de hooks y `.gitignore`:** `b45b31a` (`chore(security): configure fail-closed hooks, SessionStart handoff and gitignore rules`).
- **Ramas observadas en el repositorio:**
  - `main` (intacta; sin commits ni merges aplicados)
  - `integration/sprint-1`
  - `integration/notificaciones-reales` (`0ac3c1c`)
  - `agent/review/sprint-1-visual-demo` (`2096cf9`)
  - `chore/agy-audit`
  - Ramas en worktrees activos de subagentes (`~/.agys/profiles/karoll/.gemini/antigravity-cli/worktrees/20c47763-743f-4efd-80c2-87004fe489ac/`):
    - `agent/classifier/clasificacion` (`9ae5001`)
    - `agent/parser/t01-domain-models` (`3566d32`)
    - `agent/feedback/bandeja-pendientes` (`7505f2d`)
    - `agent/parser/notificaciones` (`b4c4de4`)
- **Docker (`flutter-env` / `finazaap-flutter`):** Contenedor activo. Validación E2E en conversación limpia `524dbf94-a0d3-4c0a-87e4-c34c214650f4` completada con éxito (`SessionStart`, lectura de handoff, `git status/branch` sin errores de sandbox, bloqueo `deny` de `.env`, permiso `allow` de `.env.example` y hook `Stop` ejecutado sin bloqueos).

---

## 2. Configuración Aplicada y Portabilidad

### Portable en el repositorio (versionado en Git)
- `AGENTS.md`: Punto de entrada corto con arranque obligatorio de handoff, reglas operativas esenciales, comandos Docker, archivos protegidos, flujo `spec -> plan -> tasks -> implement -> test` e índice documental.
- `.agents/hooks.json` (resuelve raíz vía `git rev-parse --show-toplevel` para raíz del repo, `.agents/` y worktrees):
  - `SessionStart` → `.agents/hooks/session_start_handoff.sh` (inyecta `ARRANQUE OBLIGATORIO (Moneo)`).
  - `PreToolUse` → `.agents/hooks/security_guard.py` (*fail-closed* sobre `read_file|view_file|write_file|write_to_file|edit_file|replace_file_content|multi_replace_file_content|run_command|shell_exec`).
  - `PreToolUse` → `.agents/hooks/check_protected_files.py` (*fail-closed* para archivos protegidos).
  - `PostToolUse` → `.agents/hooks/post_edit_analyze.sh` (`docker-compose exec -T flutter-env dart analyze` solo al editar `.dart`, `pubspec.yaml` o `analysis_options.yaml`).
  - `Stop` → `.agents/hooks/pre_stop_test.sh` (`docker-compose exec -T flutter-env flutter test -j 1` cuando `fullyIdle=true` y `continuationActive=false`; falla con `decision: "continue"` si `flutter-env` no está activo).
- `.gitignore`: Excluye `.env`/`.env.*` (conservando `.env.example`, `.env.template`, `.env.sample`), claves/certificados/keystores/credenciales, cajas Hive/DBs locales reales, estado local del agente, handoffs privados (`*.private.md`, `docs/handoff/.local/`) y cobertura (`coverage/`, `*.lcov`), manteniendo `.agents/skills/`, `.agents/rules/`, `.agents/hooks/` y fixtures sintéticos.

### Dependiente del perfil local (fuera del repositorio)
- `/Users/jesusmartinez/.agys/profiles/karoll/.gemini/antigravity-cli/settings.json`: Contiene el bloque secundario `"permissions"` con reglas `command(...)` (`deny` para `adb uninstall*`, `adb shell pm clear*`, `adb shell am force-stop*`, `adb install -d*`; `ask` para `adb install*`, `flutter install*`, `git push*`, `git merge*`, `git rebase*`; `allow` para `docker-compose *`, `docker exec finazaap-flutter *`, `git status*`, `git diff*`, `git log*`, `git branch*`, `git worktree*`), conservando `model`, `statusLine` y `trustedWorkspaces`. En otro equipo/perfil se replica manualmente o vía `/permissions`; la capa principal sigue siendo `.agents/hooks.json`.

---

## 3. Mapa Real de Restricciones vs. Instrucciones

- **Protección técnica real (Hooks en `.agents/hooks.json` + `permissions` en `settings.json`):**
  - `deny` para lectura/escritura en `.env`, `.env.*` (salvo `.env.example`, `.env.template`, `.env.sample`), claves, certificados, keystores, credenciales y escritura directa en `.git/`.
  - `deny` para `adb uninstall`, `adb shell pm clear`, `adb shell am force-stop`, `adb install -d` y borrado de datos de app.
  - `deny` para envío por red de secretos, notificaciones o datos financieros; `force_ask` en comandos de red que mencionen términos/rutas sensibles (sin bloquear `curl`/`wget` normales).
  - `force_ask` para `adb install` / `flutter install`, `git merge` / `rebase` / `push`, archivos protegidos (edición directa, shell o `build_runner`) y migraciones de esquema/datos.
  - Inyección automática de arranque (`SessionStart`) y gate de pruebas en `Stop`.
- **Dependiente de instrucciones en `AGENTS.md` (sin bloqueo técnico determinista):**
  - Orden exacto de lectura de handoff y actualización al final de la sesión.
  - No instalar herramientas en el host fuera de comandos interceptados.
  - Distinción real vs demo vs stub y política de no tratar una URL por sí sola como evidencia de fraude en lógica de negocio.
  - No redactar secretos ni contenido íntegro de notificaciones reales en documentos/logs cuando no provengan de archivos bloqueados.

---

## 4. Próximos Pasos Pendientes

- Revisión humana de `agent/config/contexto-y-seguridad` y decisión de merge (sin merge automático a `main`).
- Revisión e integración de `integration/notificaciones-reales` vs `integration/sprint-1` (pendiente de decisión del usuario).
- Ejecución E2E Maestro en emulador/dispositivo físico (`.maestro/sprint_1_notificaciones.yaml`), actualmente pendiente de dispositivo/JRE.
