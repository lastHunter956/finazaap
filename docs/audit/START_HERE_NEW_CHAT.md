# Prompt de Arranque para Nuevo Chat (`docs/audit/START_HERE_NEW_CHAT.md`)

Copia y pega este bloque al iniciar un chat nuevo con **Gemini 4 Hydrogen (Medium)**:

---

```text
Trabajas en Moneo (finazaap) en /Volumes/ADATA SD620/Programacion 7.0/moneo/finazaap usando Gemini 4 Hydrogen (Medium).

REGLAS OBLIGATORIAS:
1. Lee en orden antes de tocar nada:
   - docs/handoff/CURRENT_STATE.md
   - docs/handoff/ACTIVE_TASK.md
   - docs/handoff/DECISIONS.md
   - docs/handoff/LESSONS.md
   - docs/audit/CONTINUITY_STATE.md
   - docs/audit/DECISIONS.md
   - docs/audit/EXECUTION_PLAN.md
2. Verifica estado real: git status -sb, git branch -a, git worktree list, docker ps --filter name=finazaap-flutter.
3. LÍMITES ESTRICTOS:
   - NUNCA hagas commits en main ni merge a main. Usa una rama agent/<nombre>/<tarea>.
   - NO limpies ramas, worktrees o procesos ajenos.
   - NO toques datos reales, saldos de usuario ni migres cifrado sin aprobación explícita.
   - NO modifiques archivos protegidos (transaction_service.dart, credit_card_calculator.dart, *.g.dart, build.gradle, AndroidManifest.xml, lib/core/security/*) sin aprobación explícita.
   - Flutter/Dart SOLO en Docker:
     docker-compose exec -T flutter-env dart analyze
     docker-compose exec -T flutter-env flutter test --no-pub -j 1
4. MULTIAGENTE Y CUOTA:
   - Máximo 2 subagentes simultáneos con Model: "inherit" (prohibido cambiar a Claude/GPT o modelos con cobro adicional; sin delegación recursiva).
   - Trabaja en lotes pequeños y actualiza docs/audit/CONTINUITY_STATE.md al cerrar cada lote.
   - Ni la lectura de código ni los tests garantizan ausencia de errores ni sustituyen la prueba en el teléfono.

PRIMER PASO:
- Revisa docs/audit/EXECUTION_PLAN.md y docs/audit/CONTINUITY_STATE.md.
- Si estás iniciando la ejecución desde cero, toma Ola 0 (T0.1 y T0.2) desde docs/audit/tasks/.
- Para Ola 1 en adelante, verifica si la tarea requiere decisiones abiertas (D1–D8) o aprobación de archivo protegido y DETENTE a pedir confirmación antes de editar.

REPORTE AL TERMINAR UNA TAREA:
- ID de tarea, rama y archivos modificados (solo dentro de "Archivos permitidos").
- Salida literal de dart analyze y flutter test --no-pub -j 1 en Docker.
- Actualización breve en docs/audit/CONTINUITY_STATE.md y siguiente tarea recomendada.
```
