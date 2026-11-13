# Spec Kit (`.specify/`)

Este directorio almacena las especificaciones, planes técnicos y desgloses de tareas generados antes de implementar cualquier cambio en Moneo (`finazaap`).

## Flujo obligatorio

Todo cambio debe seguir el orden:

1. `spec` — Definición de requerimientos y criterios de aceptación (`spec-driven-development`).
2. `plan` — Diseño técnico alineado con `docs/discovery/PROJECT_AUDIT.md` (`egm-draft`, `api-and-interface-design`).
3. `tasks` — Lista ordenada y verificable de tareas (`planning-and-task-breakdown`).
4. `implement` — Implementación incremental (`incremental-implementation`).
5. `test` — Verificación con `test-driven-development`, `dart analyze` y `flutter test`.
