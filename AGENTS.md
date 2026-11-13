# AGENTS.md — Guía Raíz para Agentes en Moneo (`finazaap`)

> **Fuente de verdad del estado actual:** [PROJECT_AUDIT.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/discovery/PROJECT_AUDIT.md)  
> **Inventario de skills instaladas:** [SKILLS_INSTALLED.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/discovery/SKILLS_INSTALLED.md)

Moneo (`finazaap`) es una aplicación de finanzas personales en Flutter/Dart, **100% offline**, con asistente de IA on-device (`flutter_gemma`) y soporte de build/test mediante Docker (`finazaap-flutter`).

---

## 1. Comandos Docker para Build, Análisis y Tests

En macOS el SDK de Flutter/Dart no está en el PATH del host; toda compilación, análisis y prueba se ejecuta dentro del contenedor `finazaap-flutter` (`docker-compose.yml` / `Makefile`):

```bash
# Construir e iniciar el contenedor en segundo plano
make build
make up

# Abrir shell interactiva dentro del contenedor
make shell

# Análisis estático y formato
docker-compose exec flutter-env dart analyze
docker-compose exec flutter-env dart format --output=none --set-exit-if-changed .

# Ejecutar suite de pruebas
docker-compose exec flutter-env flutter test
docker-compose exec flutter-env flutter test test/widget_test.dart

# Regenerar adaptadores Hive tras cambios aprobados en modelos
docker-compose exec flutter-env dart run build_runner build --delete-conflicting-outputs

# Compilar APK Release o ejecutar Web
make apk
make web

# Limpiar y detener contenedor
make clean
make down
```

---

## 2. Reglas de Rama, Commits y Worktrees

- **Prohibido hacer commits directos en `main`.**
- **Rama obligatoria por tarea:** todo trabajo de agente debe vivir en una rama con formato:
  `agent/<nombre>/<tarea>` (ejemplo: `agent/claude/notificaciones-bancarias`).
- **Trabajo en paralelo (`git worktree`):** cuando varios agentes trabajen simultáneamente, cada uno debe usar su propio worktree sobre su rama `agent/<nombre>/<tarea>` para evitar colisiones en el directorio de trabajo.
- **No commitear artefactos pesados ni secretos:** `web/models/gemma.litertlm` y `assets/models/gemma.litertlm` (~5.17 GB) ya generan peso excesivo en Git; nunca agregues `.hive`, `.jks`, `.keystore`, `.env` ni binarios nuevos.
- Sigue siempre la skill `git-workflow-and-versioning`.

---

## 3. Lista de Archivos Protegidos

Queda **prohibido** modificar cualquiera de los siguientes archivos sin **aprobación explícita del usuario** (reforzado por `.agents/rules/archivos-protegidos.md` y el hook `PreToolUse` `.agents/hooks/check_protected_files.py`):

| Ruta / Patrón | Motivo de protección |
| :--- | :--- |
| `lib/data/transaction_service.dart` | Única puerta de entrada para saldos en `SharedPreferences` y sincronización con `Hive` / `ResponsibilityService`. |
| `lib/data/credit_card_calculator.dart` | Fuente de verdad única para cálculo de deuda y cuotas de tarjetas de crédito. |
| `lib/data/model/*.g.dart` | Código generado por `build_runner` para adaptadores Hive (`typeId: 1` y `2`); riesgo de corrupción de datos locales. |
| `android/app/build.gradle` | Configuración de compilación Android, `applicationId`, SDKs y firma. |
| `android/app/src/main/AndroidManifest.xml` | Permisos del sistema, servicios nativos y componentes Android. |
| `lib/core/security/*` | Cifrado local (`encryption_service.dart`), manejo de llaves y seguridad de acceso. |

---

## 4. Flujo Obligatorio: Spec Kit + EGM

Todo cambio debe ejecutarse en este orden estricto (definido en `.agents/rules/flujo-desarrollo.md`):

`spec` → `plan` → `tasks` → `implement` → `test`

1. **`spec` (`.specify/`):** Usa `spec-driven-development` para definir alcance, restricciones y criterios de aceptación antes de tocar código.
2. **`plan` (`.specify/`):** Contrasta el diseño contra `docs/discovery/PROJECT_AUDIT.md`. Para decisiones complejas o ambiguas, usa las skills EGM (`egm-bootstrap`, `egm-brainstorm`, `egm-draft`, `egm-review`, `egm-review-loop`, `egm-drift-report`, `egm-resolve`) y `doubt-driven-development`.
3. **`tasks` (`.specify/`):** Desglosa el plan en tareas pequeñas con `planning-and-task-breakdown`.
4. **`implement`:** Ejecuta en cortes incrementales (`incremental-implementation`) aplicando las skills `dart-*` / `flutter-*` correspondientes.
5. **`test`:** Verifica con `test-driven-development`, `dart analyze`, `flutter test` y flujos E2E en `.maestro/`. Para revisión final usa `code-review-and-quality` y `doubt-driven-development`.

### Directrices de Calidad y Eficiencia (FASE 4.5)
- **`no-new-files-by-default`:** Edita archivos existentes siempre que sea posible. No crees archivos nuevos innecesarios, duplicados ni micro-archivos de una sola función/clase salvo que la arquitectura por capas o una spec aprobada lo exija.
- **`DRY-first`:** Antes de escribir lógica o UI nueva, busca helpers, utilidades y servicios existentes (por ejemplo `AppColors` en `lib/themes/app_colors.dart`, `CurrencyHelper` en `lib/utils/currency_helper.dart`, `TransactionService`, `ResponsibilityService`) para reutilizarlos en lugar de duplicar código.

---

## 5. Índice de Skills Instaladas (`./.agents/skills/`)

Las **48 skills curadas** ya están instaladas localmente (45 externas + 3 de dominio Moneo). **No dupliques skills ni crees guías paralelas** (por ejemplo: *usa `test-driven-development` o `dart-add-unit-test` para escribir tests, no crees tu propia skill de testing*).

### A. Dominio Moneo (`moneo-*`)
- `moneo-notification-parser`: Extracción estructurada de notificaciones bancarias (`{tipo, monto, comercio, fecha, cuenta}`) y bloqueo anti-fraude de links.
- `moneo-transaction-classifier`: Clasificación en `gasto` / `ingreso` / `transferencia-propia` / `sospechosa` (anti-fraude → Hive `learned_patterns` → reglas deterministas → Gemma solo como respaldo).
- `moneo-feedback-loop`: Bandeja de pendientes, modo `"aceptar todo"` (alta confianza) y actualización de `learned_patterns`.

### B. Spec Kit y Elephant Goldfish Model (EGM)
- `spec-driven-development`: Crear especificaciones y PRDs antes de codificar.
- `egm-bootstrap`, `egm-brainstorm`, `egm-draft`, `egm-drift-report`, `egm-resolve`, `egm-review`, `egm-review-loop`: Gestión de decisiones, lluvia de ideas, borradores, detección de deriva y ciclos de revisión.

### C. Proceso de Ingeniería, Calidad, Seguridad y UI
- `using-agent-skills`: Descubrir y elegir qué skill activar al iniciar una tarea.
- `context-engineering`: Optimizar contexto, compactación y carga selectiva de archivos.
- `interview-me` / `idea-refine`: Aclarar requerimientos ambiguos o refinar ideas antes de planificar.
- `planning-and-task-breakdown`: Dividir una spec en tareas ordenadas e implementables.
- `incremental-implementation`: Entregar cambios en cortes pequeños y verificables.
- `constraint-driven-development`: Definir y proteger umbrales de calidad sin relajar checks.
- `doubt-driven-development`: Revisión adversarial de supuestos en cambios críticos.
- `test-driven-development`: Ciclo red-green-refactor para cualquier lógica o bugfix.
- `code-review-and-quality`: Revisión multi-eje antes de mergear.
- `code-simplification`: Simplificar código complejo sin alterar su comportamiento.
- `debugging-and-error-recovery`: Depuración sistemática de causa raíz.
- `security-and-hardening`: Threat modeling (STRIDE), validación de entradas y manejo de secretos.
- `security-audit`: Auditoría de seguridad OWASP, CWE Top 25, CVSS y dependencias.
- `mobile-app-ui-design`: Diseño UI/UX móvil pulido (jerarquía, 8-point grid, 60/30/10, estados vacíos/error).
- `api-and-interface-design`: Diseño de contratos entre módulos, servicios y capa nativa.
- `documentation-and-adrs`: Registro de ADRs y documentación técnica.
- `source-driven-development`: Verificar decisiones contra documentación oficial o código real del repo.
- `deprecation-and-migration`: Migrar código muerto o esquemas sin romper datos existentes.
- `git-workflow-and-versioning`: Ramas, commits atómicos, worktrees y PRs.
- `ci-cd-and-automation`: Automatización de checks en CI/Docker.

### D. Flutter y Dart
- `flutter-apply-architecture-best-practices`: Estructurar capas UI, lógica y datos.
- `flutter-add-widget-test` / `flutter-add-integration-test`: Pruebas de widgets e integración.
- `flutter-build-responsive-layout` / `flutter-fix-layout-issues`: Layouts adaptativos y corrección de overflows.
- `flutter-implement-json-serialization`: Serialización JSON manual `fromJson`/`toJson`.
- `flutter-setup-localization`: Configuración de `intl` y `flutter_localizations`.
- `dart-run-static-analysis` / `dart-fix-runtime-errors`: Análisis estático (`dart analyze`) y corrección de errores en runtime.
- `dart-add-unit-test` / `dart-generate-test-mocks` / `dart-collect-coverage`: Pruebas unitarias, mocks con `mockito` y cobertura LCOV.
- `dart-use-pattern-matching` / `dart-use-path-package`: Idiomaticidad Dart 3 y manejo seguro de rutas.
- `dart-write-documentation`: Documentación Dartdoc (`///`).
- `dart-resolve-package-conflicts`: Resolver conflictos en `pubspec.yaml` / `pub get`.
