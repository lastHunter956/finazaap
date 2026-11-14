#!/usr/bin/env sh
# Hook SessionStart: inyecta instrucción de lectura de handoff y verificación de estado real.
cat <<'EOF'
{
  "injectSteps": [
    {
      "systemMessage": {
        "systemMessage": "ARRANQUE OBLIGATORIO (Moneo): Antes de proponer o ejecutar cambios, lee docs/handoff/CURRENT_STATE.md, ACTIVE_TASK.md, DECISIONS.md y LESSONS.md; luego verifica el estado real con git status/branch/worktree y Docker (finazaap-flutter). Trata el handoff como contexto previo, no como evidencia definitiva."
      }
    }
  ]
}
EOF
