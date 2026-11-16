# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama actual:** `main` (`dc6d660`)
> **Estado:** Consolidadas en `main` `integration/onboarding-y-mejoras-ui` (`b8a00ba`), `integration/pendientes-web-y-perf` (`59a22c0`) e `integration/maestro-configuracion` (`dc6d660`), verificadas en Docker (`244/244` tests en Flutter `3.44.2`, `flutter build web` OK, `12/13` en `test_maestro_security_suite.py`).

## Pendientes reales
1. [ ] Revisar los 9 `.maestro/verify_*.yaml` sin trackear en `wt-maestro-agentic` (`agent/maestro/configuracion-agentica`) antes de eliminar ese worktree.
2. [ ] Construir `finazaap-maestro:local` si se desea ejecutar `test_13` de aislamiento de red Maestro.
3. [ ] `git push` a `origin/main` (solo con autorización explícita del usuario).
4. [ ] Validación ampliada de notificaciones bancarias reales en dispositivo (sesión futura).
