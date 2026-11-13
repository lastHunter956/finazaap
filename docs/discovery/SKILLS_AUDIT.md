# Auditoría y Curaduría de Skills — Moneo (`finazaap`)

> **Fecha:** 2026-11-13  
> **Estado:** Completada (FASE 8)  
> **Alcance:** `./.agents/skills/`, `AGENTS.md`, `.agents/agents/` (sin cambios en código de la app)

---

## 1. Resumen Ejecutivo (Antes vs Después)

| Métrica | Inicial | Final Curado | Cambio |
| :--- | :---: | :---: | :---: |
| **Total de skills en `./.agents/skills/`** | **62** | **48** | **-14** |
| Skills externas | 59 | 45 | -16 eliminadas, +2 instaladas |
| Skills de dominio Moneo (`moneo-*`) | 3 | 3 | Intactas (solo actualización de referencia) |
| Directrices de eficiencia/calidad en `AGENTS.md` | — | +2 | `no-new-files-by-default` y `DRY-first` |

---

## 2. Clasificación Inicial (62 skills)

- **ESENCIAL (19):** `moneo-notification-parser`, `moneo-transaction-classifier`, `moneo-feedback-loop`, `spec-driven-development`, `planning-and-task-breakdown`, `incremental-implementation`, `test-driven-development`, `code-review-and-quality`, `git-workflow-and-versioning`, `security-and-hardening`, `debugging-and-error-recovery`, `context-engineering`, `using-agent-skills`, `dart-run-static-analysis`, `dart-add-unit-test`, `dart-use-pattern-matching`, `flutter-apply-architecture-best-practices`, `flutter-add-widget-test`, `flutter-fix-layout-issues`.
- **ÚTIL (27):** `egm-bootstrap`, `egm-brainstorm`, `egm-draft`, `egm-drift-report`, `egm-resolve`, `egm-review`, `egm-review-loop`, `api-and-interface-design`, `code-simplification`, `constraint-driven-development`, `deprecation-and-migration`, `documentation-and-adrs`, `doubt-driven-development`, `idea-refine`, `interview-me`, `source-driven-development`, `ci-cd-and-automation`, `dart-collect-coverage`, `dart-fix-runtime-errors`, `dart-generate-test-mocks`, `dart-resolve-package-conflicts`, `dart-use-path-package`, `dart-write-documentation`, `flutter-add-integration-test`, `flutter-build-responsive-layout`, `flutter-implement-json-serialization`, `flutter-setup-localization`.
- **REDUNDANTE (3):** `code-review`, `frontend-ui-engineering`, `performance-optimization`.
- **CONFLICTIVA (4):** `dart-use-primary-constructors`, `flutter-setup-declarative-routing`, `flutter-use-http-package`, `dart-migrate-to-checks-package`.
- **SIN USO (9):** `add-community-extension`, `browser-testing-with-devtools`, `observability-and-instrumentation`, `shipping-and-launch`, `dart-build-cli-app`, `dart-setup-ffi-assets`, `dart-use-doc-examples`, `dart-use-ffigen`, `flutter-add-widget-preview`.

---

## 3. Skills Eliminadas (16) y Motivo

| Skill eliminada | Categoría | Motivo / Reemplazo |
| :--- | :---: | :--- |
| `code-review` (`github/spec-kit`) | Redundante | Específica de `spec-kit`; reemplazada por `code-review-and-quality`. |
| `frontend-ui-engineering` (`addyosmani`) | Redundante | Orientada a React/TSX/Tailwind; reemplazada por `mobile-app-ui-design` + skills `flutter-*`. |
| `performance-optimization` (`addyosmani`) | Redundante | Orientada a Web Vitals (LCP/INP/CLS) y Node; no aplica a Flutter móvil. |
| `dart-use-primary-constructors` | Conflictiva | Exige Dart 3.12+/3.13+; `pubspec.yaml` usa `sdk: '>=3.0.0 <4.0.0'`. |
| `flutter-setup-declarative-routing` | Conflictiva | Impone `go_router`, no utilizado en Moneo. |
| `flutter-use-http-package` | Conflictiva | Impone `package:http`, violando la arquitectura 100% offline. |
| `dart-migrate-to-checks-package` | Conflictiva | Impone `package:checks` frente a `expect()` estándar de `flutter_test`. |
| `add-community-extension` | Sin uso | Catálogo comunitario de Spec Kit. |
| `browser-testing-with-devtools` | Sin uso | Chrome DevTools web; Moneo usa Flutter móvil + `.maestro/`. |
| `observability-and-instrumentation` | Sin uso | Telemetría/APM SaaS incompatible con app offline privada. |
| `shipping-and-launch` | Sin uso | Checklist SaaS/web (DNS, CDN, SSL). |
| `dart-build-cli-app` | Sin uso | CLIs con `package:args`. |
| `dart-setup-ffi-assets` | Sin uso | C/C++ nativo vía `hook/build.dart` (además marcada `Critical Risk` por Snyk). |
| `dart-use-doc-examples` | Sin uso | `{@example}` para librerías en pub.dev (`publish_to: 'none'`). |
| `dart-use-ffigen` | Sin uso | Bindings FFI desde C/Obj-C/Swift. |
| `flutter-add-widget-preview` | Sin uso | Previewer web que prohíbe `dart:io`/`dart:ffi`. |

---

## 4. Skills Evaluadas e Instaladas (Gaps FASE 4 y 4.5)

| Gap | Skill candidata | Resultado | Auditoría |
| :--- | :--- | :---: | :--- |
| Seguridad móvil / OWASP | `security-audit` (`netresearch/security-audit-skill`) | **Instalada** | YAML válido; sin llamadas de red destructivas ni conflictos con Moneo (`Low Risk` Snyk, `0 alerts` Socket). |
| Performance Flutter | `flutter-performance` (`flutter/skills` → no existe; `zakariaf/Flutter-Skills` → instalada y **descartada**) | **Rechazada / Eliminada** | Imponía Riverpod (`ConsumerWidget`, `WidgetRef`, `ref.watch(select)`, `state-management-riverpod`), incompatible con Moneo (`ChangeNotifier`). |
| Design taste móvil | `mobile-app-ui-design` (`ceorkm/mobile-app-ui-design`) | **Instalada** | YAML válido; 0 llamadas de red, 0 credenciales/comandos destructivos, 0 imposiciones de state management (`Low Risk` Snyk, `0 alerts` Socket). |
| Eficiencia de tokens | `context-engineering` (ya instalada) | **Cubierta (~85%)** | Mantiene secciones de *Context Budget Management* y compactación; no requiere skill adicional. |
| Evitar file bloat | `no-new-files-by-default` | **Añadida a `AGENTS.md`** | Directriz explícita para editar archivos existentes antes de crear nuevos. |
| Reutilización (DRY) | `DRY-first` | **Añadida a `AGENTS.md`** | Directriz explícita para buscar `AppColors`, `CurrencyHelper`, `TransactionService`, etc. antes de escribir código nuevo. |

---

## 5. Verificación de Referencias y Estado Final

- `moneo-feedback-loop/SKILL.md`: referencia actualizada de `frontend-ui-engineering` a `mobile-app-ui-design`.
- `.agents/agents/reviewer-goldfish.md`: referencia actualizada de `code-review` (Spec Kit) a `code-review-and-quality`.
- `AGENTS.md`: índice actualizado con las **48 skills curadas** y las 2 directrices de FASE 4.5.
- Verificación por `grep` en `AGENTS.md`, `.agents/agents/*.md`, `.agents/rules/*.md` y `.agents/skills/moneo-*/SKILL.md`: **0 referencias rotas** a las skills eliminadas.
