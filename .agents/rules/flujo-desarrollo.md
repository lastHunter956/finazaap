---
trigger: always_on
---

# Regla: Flujo Obligatorio de Desarrollo

Todo cambio funcional o técnico en el repositorio debe seguir estrictamente el flujo:

`spec` → `plan` → `tasks` → `implement` → `test`

## Etapas y skills asociadas

1. **`spec` (Especificación):** Define qué se va a construir, alcance, criterios de aceptación y restricciones antes de escribir código.
   - Usa la skill ya instalada `spec-driven-development` (`.agents/skills/spec-driven-development/SKILL.md`) y los artefactos en `.specify/`.
2. **`plan` (Planificación):** Diseña la arquitectura de la solución y valida decisiones técnicas contra [PROJECT_AUDIT.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/discovery/PROJECT_AUDIT.md).
   - Apóyate en `egm-brainstorm` / `egm-draft` / `doubt-driven-development` cuando existan decisiones de alto riesgo.
3. **`tasks` (Desglose de tareas):** Divide el plan en tareas pequeñas, ordenadas y verificables.
   - Usa `planning-and-task-breakdown`.
4. **`implement` (Implementación incremental):** Ejecuta en cortes pequeños y verificables.
   - Usa `incremental-implementation` y las skills específicas de `flutter-*` / `dart-*` ya instaladas.
5. **`test` (Pruebas y validación):** Ninguna tarea se considera terminada sin pruebas y análisis estático.
   - Usa `test-driven-development`, `dart-add-unit-test`, `flutter-add-widget-test` y `dart-run-static-analysis`.
   - Para flujos E2E, registra escenarios en `.maestro/`.

## Restricción de skills

No crees skills nuevas ni dupliques instrucciones de testing, git o especificación: reutiliza siempre las 59 skills instaladas en `./.agents/skills/`.
