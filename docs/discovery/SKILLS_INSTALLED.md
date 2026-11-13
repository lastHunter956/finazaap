# Reporte de Instalación de Skills Externas — Moneo (`finazaap`)

> **Fecha:** 2026-11-13  
> **Entorno:** `npx 11.19.0` (`skills@1.8.1`), `agy 1.5.8` (perfil `karoll`)  
> **Alcance:** Instalación 100% local al workspace en `./.agents/skills/` (sin instalaciones globales).

---

## 1. Resumen por Repositorio

| Repositorio | Cantidad | Versión / Lockfile | Ruta de instalación | Observaciones |
| :--- | :---: | :--- | :--- | :--- |
| `dart-lang/skills` | 15 | `skills-lock.json` v2 (hashes SHA-256) | `./.agents/skills/dart-*` | Instaladas inicialmente; luego sobrescritas con la misma base por `flutter/agent-plugins`. |
| `flutter/agent-plugins` | 25 (15 `dart-*` + 10 `flutter-*`) | `skills-lock.json` v2 | `./.agents/skills/dart-*` y `./.agents/skills/flutter-*` | Incluye las 15 de `dart-lang/skills` más 10 específicas de Flutter. |
| `github/spec-kit` | 2 | `skills-lock.json` v2 | `./.agents/skills/add-community-extension`, `./.agents/skills/code-review` | — |
| `google/elephant-goldfish-model` | 7 | `skills-lock.json` v2 | `./.agents/skills/egm-*` | — |
| `addyosmani/agent-skills` | 25 | `skills-lock.json` v2 | `./.agents/skills/*` | — |
| **Total en `./.agents/skills/`** | **59 skills únicas** | `skills-lock.json` (raíz del repo) | `./.agents/skills/<nombre-skill>/` | **0 skills instaladas en rutas globales.** |

---

## 2. Lista Completa de Skills Instaladas (59)

### `flutter/agent-plugins` (incluye las 15 de `dart-lang/skills`) — 25 skills
- `dart-add-unit-test` -> `./.agents/skills/dart-add-unit-test`
- `dart-build-cli-app` -> `./.agents/skills/dart-build-cli-app` *(con `references/`)*
- `dart-collect-coverage` -> `./.agents/skills/dart-collect-coverage`
- `dart-fix-runtime-errors` -> `./.agents/skills/dart-fix-runtime-errors`
- `dart-generate-test-mocks` -> `./.agents/skills/dart-generate-test-mocks`
- `dart-migrate-to-checks-package` -> `./.agents/skills/dart-migrate-to-checks-package`
- `dart-resolve-package-conflicts` -> `./.agents/skills/dart-resolve-package-conflicts`
- `dart-run-static-analysis` -> `./.agents/skills/dart-run-static-analysis`
- `dart-setup-ffi-assets` -> `./.agents/skills/dart-setup-ffi-assets`
- `dart-use-doc-examples` -> `./.agents/skills/dart-use-doc-examples`
- `dart-use-ffigen` -> `./.agents/skills/dart-use-ffigen`
- `dart-use-path-package` -> `./.agents/skills/dart-use-path-package`
- `dart-use-pattern-matching` -> `./.agents/skills/dart-use-pattern-matching`
- `dart-use-primary-constructors` -> `./.agents/skills/dart-use-primary-constructors`
- `dart-write-documentation` -> `./.agents/skills/dart-write-documentation`
- `flutter-add-integration-test` -> `./.agents/skills/flutter-add-integration-test`
- `flutter-add-widget-preview` -> `./.agents/skills/flutter-add-widget-preview`
- `flutter-add-widget-test` -> `./.agents/skills/flutter-add-widget-test`
- `flutter-apply-architecture-best-practices` -> `./.agents/skills/flutter-apply-architecture-best-practices`
- `flutter-build-responsive-layout` -> `./.agents/skills/flutter-build-responsive-layout`
- `flutter-fix-layout-issues` -> `./.agents/skills/flutter-fix-layout-issues`
- `flutter-implement-json-serialization` -> `./.agents/skills/flutter-implement-json-serialization`
- `flutter-setup-declarative-routing` -> `./.agents/skills/flutter-setup-declarative-routing`
- `flutter-setup-localization` -> `./.agents/skills/flutter-setup-localization`
- `flutter-use-http-package` -> `./.agents/skills/flutter-use-http-package`

### `github/spec-kit` — 2 skills
- `add-community-extension` -> `./.agents/skills/add-community-extension`
- `code-review` -> `./.agents/skills/code-review`

### `google/elephant-goldfish-model` — 7 skills
- `egm-bootstrap` -> `./.agents/skills/egm-bootstrap` *(con `references/`)*
- `egm-brainstorm` -> `./.agents/skills/egm-brainstorm`
- `egm-draft` -> `./.agents/skills/egm-draft` *(con `references/`)*
- `egm-drift-report` -> `./.agents/skills/egm-drift-report`
- `egm-resolve` -> `./.agents/skills/egm-resolve`
- `egm-review` -> `./.agents/skills/egm-review`
- `egm-review-loop` -> `./.agents/skills/egm-review-loop`

### `addyosmani/agent-skills` — 25 skills
- `api-and-interface-design` -> `./.agents/skills/api-and-interface-design`
- `browser-testing-with-devtools` -> `./.agents/skills/browser-testing-with-devtools`
- `ci-cd-and-automation` -> `./.agents/skills/ci-cd-and-automation`
- `code-review-and-quality` -> `./.agents/skills/code-review-and-quality`
- `code-simplification` -> `./.agents/skills/code-simplification`
- `constraint-driven-development` -> `./.agents/skills/constraint-driven-development` *(con `scripts/` y `references/`)*
- `context-engineering` -> `./.agents/skills/context-engineering`
- `debugging-and-error-recovery` -> `./.agents/skills/debugging-and-error-recovery`
- `deprecation-and-migration` -> `./.agents/skills/deprecation-and-migration`
- `documentation-and-adrs` -> `./.agents/skills/documentation-and-adrs`
- `doubt-driven-development` -> `./.agents/skills/doubt-driven-development`
- `frontend-ui-engineering` -> `./.agents/skills/frontend-ui-engineering`
- `git-workflow-and-versioning` -> `./.agents/skills/git-workflow-and-versioning`
- `idea-refine` -> `./.agents/skills/idea-refine` *(con `scripts/`)*
- `incremental-implementation` -> `./.agents/skills/incremental-implementation`
- `interview-me` -> `./.agents/skills/interview-me`
- `observability-and-instrumentation` -> `./.agents/skills/observability-and-instrumentation`
- `performance-optimization` -> `./.agents/skills/performance-optimization` *(con `references/`)*
- `planning-and-task-breakdown` -> `./.agents/skills/planning-and-task-breakdown`
- `security-and-hardening` -> `./.agents/skills/security-and-hardening` *(con `references/`)*
- `shipping-and-launch` -> `./.agents/skills/shipping-and-launch`
- `source-driven-development` -> `./.agents/skills/source-driven-development`
- `spec-driven-development` -> `./.agents/skills/spec-driven-development`
- `test-driven-development` -> `./.agents/skills/test-driven-development`
- `using-agent-skills` -> `./.agents/skills/using-agent-skills`

---

## 3. Validación de Estructura, Rutas y `/skills` en `agy`

- **Verificación de `SKILL.md` y frontmatter YAML:** Las **59/59** carpetas en `./.agents/skills/` contienen `SKILL.md` con frontmatter YAML válido (`name` y `description` presentes). 2 skills incluyen `scripts/` y 6 incluyen `references/`.
- **Verificación de aislamiento local (no global):**
  - `~/.agents/skills/` (`/Users/jesusmartinez/.agys/profiles/karoll/.agents/skills/`): **No existe**.
  - `~/.gemini/config/skills/` (`/Users/jesusmartinez/.agys/profiles/karoll/.gemini/config/skills/`): **No existe**.
  - `npx --yes skills list` lista únicamente **Project Skills** en `./.agents/skills/*` para `Agents: Antigravity, Antigravity CLI, Gemini CLI`.
- **Detección en `agy` (`/skills`):**
  - El comando `/skills` es un slash command interactivo de la interfaz de usuario de `agy` que el agente no puede invocar directamente desde el chat ni desde CLI (`agy 1.5.8` no expone subcomando `agy skills`).
  - Según `agy-customizations/SKILL.md`, Antigravity descubre automáticamente las skills del proyecto en `./.agents/skills/` al iniciar una nueva sesión o recargar el contexto. **Se recomienda al usuario ejecutar `/skills` en el chat para confirmar visualmente la carga de las 59 skills.**

---

## 4. Advertencias y Notas

1. **Archivo adicional generado por `npx skills`:** La herramienta creó `skills-lock.json` en la raíz del proyecto (v2, 359 líneas) con los hashes de las 59 skills instaladas.
2. **Evaluación de riesgo reportada por `npx skills` (Snyk):** `dart-setup-ffi-assets` mostró `Critical Risk` (Gen: `Med Risk`); `add-community-extension`, `code-review`, `egm-resolve`, `egm-review` y `egm-review-loop` mostraron `Med Risk`. Ninguna presentó alertas de Socket (`0 alerts`).
3. **Sin cambios en la app:** No se modificó ningún archivo de código fuente, reglas, hooks ni subagentes.
