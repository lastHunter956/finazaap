# Paquete de Ejecución — Auditoría Profunda Moneo (`finazaap`)

> **Base verificada:** `main` @ `bab211fcc9243e89b050fd1a40cb9c25157d7fcb` (`bab211f`, árbol limpio, sin worktrees activos).  
> **Naturaleza de este paquete:** Documentación de planificación y verificación. **No se modificó código, configuración, dependencias ni archivos protegidos.**

---

## 1. Relación con `integration/ui-temas-y-asistente` y Conflictos Potenciales

### Estado en Git (verificado)
- `integration/ui-temas-y-asistente` **ya fue fusionada por `--ff-only` en `main`** (`bab211f`) y posteriormente retirada conforme a `docs/handoff/DECISIONS.md`.
- El último ajuste visual de UI (`af1fbf5`) ya forma parte de `main`.

### Superficie de archivos modificados por `ui-temas-y-asistente` (28 archivos entre `165c1c1..bab211f`)
Si existen ramas de UI futuras o trabajo visual basado en esa integración, los siguientes archivos del paquete de auditoría **comparten superficie directa** con `ui-temas-y-asistente`:

| Archivo | Tocado por UI (`165c1c1..bab211f`) | Olas que lo modifican | Riesgo de conflicto |
| :--- | :--- | :--- | :--- |
| `lib/Screens/ai_chat_screen.dart` | 4,996+ líneas cambiadas | Ola 2 (`T2.2`), Ola 3 (`T3.4`), Ola 4 (`T4.3`) | **ALTO** — preservar diseño editorial, `Perfil Cognitivo` y `MoneoHeaderBar` |
| `lib/Screens/home.dart` | +378/- líneas (`MoneoHeaderBar`, clearance) | Ola 1 (`T1.3c`), Ola 3 (`T3.3`), Ola 4 (`T4.2`) | **ALTO** — no tocar estructura de `MoneoHeaderBar` ni `scrollBottomPadding` |
| `lib/Screens/statistics.dart` | 163 líneas (`MoneoHeaderBar`, clearance) | Ola 1 (`T1.1`), Ola 4 (`T4.2`) | **MEDIO** — preservar `MoneoHeaderBar` y tokens `AppThemeData` |
| `lib/Screens/main_container.dart` | 42 líneas (`effectiveBottomClearance`) | Ola 3 (`T3.2`), Ola 4 (`T4.1`) | **MEDIO** — preservar `MoneoNavBarScope` y `effectiveBottomClearance` |
| `lib/Screens/selecctaccount.dart` | 133 líneas | Ola 1 (`T1.3c`), Ola 4 (`T4.3`) | **MEDIO** |
| `lib/Screens/responsibilities_screen.dart` | 107 líneas | Ola 1 (`T1.3c`), Ola 4 (`T4.3`) | **MEDIO** |
| `lib/Screens/categories_screen.dart` | 227 líneas | Ola 4 (`T4.1`) | **BAJO** |
| `lib/Screens/add.dart`, `add_expense.dart`, `transfer.dart`, `annual_projection_screen.dart`, `settings_screen.dart`, `pending_transactions_screen.dart` | 21–163 líneas (headers/clearance) | Ola 1, Ola 3, Ola 4 | **BAJO** (siempre que no se alteren encabezados ni paddings inferiores) |
| `lib/widgets/total_balance_widget.dart` | 550 líneas (`MoneoPressableScale`) | Ola 4 (`T4.2`) | **ALTO** — preservar animaciones `Diurno` |

**Regla de preservación UI:** Ninguna tarea de este paquete debe alterar `lib/themes/app_theme_data.dart`, `lib/widgets/liquid_glass_surface.dart`, `lib/widgets/moneo_header_bar.dart`, `lib/widgets/custom_pill_bottom_nav_bar.dart`, ni los tests `test/themes/app_theme_contrast_test.dart` y `test/widgets/ui_layout_and_navigation_test.dart`.

---

## 2. Estructura del Paquete (`docs/audit/`)

| Archivo | Propósito |
| :--- | :--- |
| [README.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/audit/README.md) | Índice, estado base y superficie de conflicto UI. |
| [FINDINGS.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/audit/FINDINGS.md) | Verificación de los **81 hallazgos** (`CONFIRMADO` / `PARCIAL` / `NO REPRODUCIDO` / `DESCARTADO`), severidad ajustada y separación medido vs estimado. |
| [DECISIONS.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/audit/DECISIONS.md) | Decisiones humanas obligatorias antes de ejecutar Olas 1–3. |
| [EXECUTION_PLAN.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/audit/EXECUTION_PLAN.md) | Plan secuencial por olas (Ola 0 → Ola 4) y matriz anti-colisión de archivos. |
| [START_HERE_NEW_CHAT.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/audit/START_HERE_NEW_CHAT.md) | Prompt corto para iniciar un nuevo chat con modelos ligeros. |
| `docs/audit/tasks/` | 17 fichas de tarea autosuficientes (`T0.1` a `T4.3`). |
