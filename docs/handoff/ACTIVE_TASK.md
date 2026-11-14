# Tarea Activa (`docs/handoff/ACTIVE_TASK.md`)

> **Rama:** `agent/config/contexto-y-seguridad`  
> **Estado:** Completada y validada (pendiente solo revisión humana y merge manual si el usuario lo aprueba)

## Objetivo
Configurar el arranque automático de contexto y las restricciones reales del agente en este workspace (`AGENTS.md`, `docs/handoff/`, `.agents/hooks.json`, `.agents/hooks/*`, `.gitignore` y bloque secundario `permissions` en `settings.json` del perfil local), sin implementar funcionalidad de Moneo ni tocar `main`.

## Plan Activo
1. [x] Crear rama `agent/config/contexto-y-seguridad` desde `0ac3c1c`.
2. [x] Aplicar `AGENTS.md`, `.gitignore`, `.agents/hooks.json` y los 5 scripts ejecutables en `.agents/hooks/` (`b45b31a`).
3. [x] Añadir bloque `"permissions"` (reglas `command(...)`) en `/Users/jesusmartinez/.agys/profiles/karoll/.gemini/antigravity-cli/settings.json` conservando `model`, `statusLine` y `trustedWorkspaces`.
4. [x] Validar en conversación limpia real (`524dbf94-a0d3-4c0a-87e4-c34c214650f4`): `SessionStart` inyectado, lectura de handoff, `git status/branch` operativos, bloqueo `deny` en `.env`, permiso `allow` en `.env.example` y `Stop` hook ejecutado sin bloqueos.
5. [x] Actualizar `docs/handoff/` y crear commits atómicos en `agent/config/contexto-y-seguridad`.

## Criterio de Término
- Todos los scripts en `.agents/hooks/` son ejecutables (`+x`) y `.agents/hooks.json` / `settings.json` son JSON válidos.
- Validación en conversación limpia real y suite `docker-compose exec -T flutter-env flutter test -j 1` verificadas tras los cambios finales.
- `main` sin cambios ni merges.
