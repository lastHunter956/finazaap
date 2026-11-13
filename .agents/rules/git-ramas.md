---
trigger: always_on
---

# Regla: Ramas Git y Prohibición de Commits en `main`

- **Prohibido hacer commits directos en `main`**. La rama `main` solo recibe cambios revisados mediante merge o Pull Request.
- **Convención obligatoria de rama:** Todo trabajo realizado por un agente debe ejecutarse en una rama con el formato:
  `agent/<nombre>/<tarea>`
  Ejemplo: `agent/claude/cifrado-hive` o `agent/codex/notificaciones-bancarias`.
- Si el trabajo requiere ejecución en paralelo entre varios agentes, usa `git worktree` apuntando a ramas `agent/<nombre>/<tarea>` independientes para evitar conflictos en el árbol de trabajo.
- Sigue la skill ya instalada `git-workflow-and-versioning` (`.agents/skills/git-workflow-and-versioning/SKILL.md`) para commits atómicos, mensajes claros, resolución de conflictos y preparación de PRs.
- **Advertencia del repositorio:** Recuerda que `web/models/gemma.litertlm` y `assets/models/gemma.litertlm` (~5.17 GB) están trackeados actualmente; no agregues binarios pesados ni archivos `.hive` / `.jks` / `.env` a tus commits.
