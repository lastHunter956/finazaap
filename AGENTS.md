# AGENTS.md — Guía Raíz para Agentes en Moneo (`finazaap`)

Moneo (`finazaap`) es una aplicación de finanzas personales en Flutter/Dart, **100% offline**, con asistente de IA on-device (`flutter_gemma`) y build/test mediante Docker (`finazaap-flutter`).

---

## 0. Arranque Obligatorio de Contexto (Toda Conversación Nueva)

1. Leer en este orden al iniciar:
   - `docs/handoff/CURRENT_STATE.md`
   - `docs/handoff/ACTIVE_TASK.md`
   - `docs/handoff/DECISIONS.md`
   - `docs/handoff/LESSONS.md`
2. **Verificar el estado real** antes de actuar: `git status`, ramas, `git worktree list`, últimos commits, estado de Docker (`finazaap-flutter`) y tareas pendientes.
3. Tratar el handoff como **contexto previo, no como evidencia definitiva**. Si falta información crítica o hay discrepancias con el repo real, **preguntar antes de actuar**.
4. Actualizar `docs/handoff/CURRENT_STATE.md` y `docs/handoff/ACTIVE_TASK.md` al final de la sesión o antes de un cambio importante.

---

## 1. Reglas Operativas Esenciales

- **Docker obligatorio:** Flutter, Dart, `build_runner` y pruebas se ejecutan **solo en Docker** (`docker-compose exec flutter-env ...` / `docker exec finazaap-flutter ...`). No instalar herramientas en el host macOS.
- **Git, ramas y política de integración autónoma:**
  - Prohibido hacer commits directos en `main`. Cada agente trabaja en `agent/<nombre>/<tarea>` y, si hay paralelismo, en su propio `git worktree`. No crear ramas nuevas sin necesidad; el handoff vive en `docs/handoff/`, no en ramas paralelas.
  - Al terminar, consolida en `integration/<feature>` si hace falta coordinación; si el trabajo es lineal, puede integrar directamente a `main`.
  - Ejecuta en Docker `dart analyze` y `flutter test -j 1`.
  - Si análisis y pruebas pasan, haz merge local a `main` con `--ff-only` cuando sea posible (si no, merge normal con mensaje claro) y vuelve a ejecutar análisis y pruebas en `main`.
  - Si pasan, elimina automáticamente: ramas `agent/*` ya contenidas en `main`, ramas `subagent-*` ya contenidas en `main`, ramas `integration/*` ya fusionadas en `main` (`git branch -d`), y worktrees limpios (`git status --porcelain` vacío) y sin procesos activos (`git worktree remove "<wt>"` entrecomillado por espacios en `/Volumes/ADATA SD620/...` + `git worktree prune`).
  - Actualiza `docs/handoff/CURRENT_STATE.md` y `docs/handoff/ACTIVE_TASK.md`. No conserves ramas ni worktrees de tareas terminadas.
- **Permite solo con aprobación explícita:**
  - `git push`.
  - `adb install` / `flutter install` (mostrando antes: commit, ruta y SHA-256 del APK, dispositivo, `applicationId`, `versionCode`, `versionName`, firma/certificado y confirmación de preservación de datos).
  - `adb uninstall`, `pm clear`, `am force-stop`, `adb install -d` (downgrade) — estrictamente prohibidos sin autorización explícita.
  - Acceso o envío de secretos, claves, credenciales o datos financieros.
  - Migraciones destructivas de datos.
  - Cualquier acción irreversible fuera del repositorio local (y cambios sobre los Archivos Protegidos de la sección 3).
- **Honestidad técnica:** Distinguir explícitamente entre implementación **real**, **demo** y **stub**.
- **Privacidad y seguridad de notificaciones:**
  - No leer ni persistir notificaciones de apps no seleccionadas por el usuario.
  - No enviar datos financieros ni contenido de notificaciones a servicios externos.
  - Nunca seguir, abrir ni resolver URLs recibidas en notificaciones.
  - No tratar una URL por sí sola como evidencia de fraude.
- **Secretos y datos sensibles:** Prohibido leer, modificar o incluir secretos, claves, tokens, certificados, datos financieros reales, contenido íntegro de notificaciones reales o identificadores sensibles en documentos, fixtures, commits o logs.

---

## 2. Comandos Docker Frecuentes

```bash
make up
docker-compose exec flutter-env dart analyze
docker-compose exec flutter-env dart format --output=none --set-exit-if-changed .
docker-compose exec flutter-env flutter test -j 1
```

---

## 3. Archivos Protegidos (Requieren Aprobación Explícita)

Reforzado por `.agents/rules/archivos-protegidos.md`, `.agents/hooks/security_guard.py` y `.agents/hooks/check_protected_files.py`:
- `lib/data/transaction_service.dart` (saldos y sincronización Hive/ResponsibilityService)
- `lib/data/credit_card_calculator.dart` (cálculo de deuda y cuotas)
- `lib/data/model/*.g.dart` (adaptadores Hive generados)
- `android/app/build.gradle` (configuración Android, `applicationId`, firma)
- `android/app/src/main/AndroidManifest.xml` (permisos y servicios nativos)
- `lib/core/security/*` (cifrado y llaves)

---

## 4. Flujo Obligatorio y Calidad

- **Flujo estricto:** `spec` → `plan` → `tasks` → `implement` → `test` (ver `.agents/rules/flujo-desarrollo.md`).
- **`no-new-files-by-default` y `DRY-first`:** Reutilizar helpers existentes (`AppColors`, `CurrencyHelper`, `TransactionService`, `ResponsibilityService`) antes de crear archivos nuevos.
- **Skills:** Usar las skills ya instaladas en `.agents/skills/` (no crear skills duplicadas).

---

## 5. Índice de Documentos

| Ruta | Propósito |
| :--- | :--- |
| `docs/handoff/CURRENT_STATE.md` | Estado actual verificado y puntos pendientes. |
| `docs/handoff/ACTIVE_TASK.md` | Tarea activa, plan y criterio de término. |
| `docs/handoff/DECISIONS.md` | Decisiones arquitectónicas y operativas aprobadas. |
| `docs/handoff/LESSONS.md` | Lecciones aprendidas y errores previos a evitar. |
| `docs/discovery/` | Auditorías (`PROJECT_AUDIT.md`, `SKILLS_INSTALLED.md`, `SPRINT_1_REPORT.md`). |
| `.specify/` | Especificaciones, planes y tareas (cuando estén presentes). |
