#!/usr/bin/env sh
# Hook Stop: ejecuta `docker-compose exec -T flutter-env flutter test -j 1` antes de finalizar.
# Nunca declara éxito silencioso si las pruebas no pudieron ejecutarse.

PAYLOAD=$(cat)

PARSE_OUT=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("INVALID|||")
    sys.exit(0)
if not isinstance(d, dict):
    print("INVALID|||")
    sys.exit(0)
cont = "yes" if d.get("continuationActive") is True else "no"
idle = "no" if d.get("fullyIdle") is False else "yes"
reason = str(d.get("terminationReason") or "")
cwd = str(d.get("cwd") or "")
print(f"{cont}|{idle}|{reason}|{cwd}")
' 2>/dev/null)

CONT=$(printf '%s' "$PARSE_OUT" | cut -d'|' -f1)
IDLE=$(printf '%s' "$PARSE_OUT" | cut -d'|' -f2)
TERM_REASON=$(printf '%s' "$PARSE_OUT" | cut -d'|' -f3)
CWD=$(printf '%s' "$PARSE_OUT" | cut -d'|' -f4-)

if [ "$CONT" = "INVALID" ]; then
  echo "[pre_stop_test] Omitido con motivo: payload JSON de Stop inválido." >&2
  printf '{}\n'
  exit 0
fi

if [ "$CONT" = "yes" ]; then
  echo "[pre_stop_test] Omitido con motivo: continuationActive=true (evita bucle infinito de Stop)." >&2
  printf '{}\n'
  exit 0
fi

if [ "$IDLE" = "no" ]; then
  echo "[pre_stop_test] Omitido con motivo: fullyIdle=false (tareas en segundo plano aún en ejecución)." >&2
  printf '{}\n'
  exit 0
fi

if [ "$TERM_REASON" = "USER_CANCELED" ] || [ "$TERM_REASON" = "ERROR" ]; then
  echo "[pre_stop_test] Omitido con motivo: terminationReason=$TERM_REASON." >&2
  printf '{}\n'
  exit 0
fi

if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  cd "$CWD" || true
fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || true

# Asegurar detección de Docker host en macOS dinámicamente sin fijar perfiles
if [ -z "${DOCKER_HOST:-}" ]; then
  if [ -S "/var/run/docker.sock" ]; then
    export DOCKER_HOST="unix:///var/run/docker.sock"
  elif [ -S "${HOME}/.docker/run/docker.sock" ]; then
    export DOCKER_HOST="unix://${HOME}/.docker/run/docker.sock"
  else
    SOCKET_FOUND=$(lsof -U 2>/dev/null | grep -oE '/.*docker\.sock' | head -n 1 || true)
    if [ -n "$SOCKET_FOUND" ] && [ -S "$SOCKET_FOUND" ]; then
      export DOCKER_HOST="unix://$SOCKET_FOUND"
    fi
  fi
fi

# Detectar cambios reales acumulados en la sesión (working tree o último commit si está limpio)
WORKTREE_FILES=$(git status --porcelain 2>/dev/null | awk '{print $2}')
if [ -n "$WORKTREE_FILES" ]; then
  ALL_CHANGED="$WORKTREE_FILES"
else
  ALL_CHANGED=$(git diff --name-only HEAD~1 2>/dev/null || true)
fi

HAS_FLUTTER_CHANGES=$(printf '%s\n' "$ALL_CHANGED" | grep -E '\.(dart)$|^pubspec\.(yaml|lock)$|^analysis_options\.yaml$|^android/|^ios/' || true)
HAS_MAESTRO_CHANGES=$(printf '%s\n' "$ALL_CHANGED" | grep -E '^\.maestro/|^\.agents/skills/moneo-maestro-e2e/' || true)

# 1. Si hay cambios en Maestro, ejecutar y exigir suite de Maestro
if [ -n "$HAS_MAESTRO_CHANGES" ]; then
  if [ -f ".maestro/tests/test_maestro_security_suite.py" ]; then
    MAESTRO_EXIT=0
    python3 .maestro/tests/test_maestro_security_suite.py >&2 || MAESTRO_EXIT=$?
    if [ "$MAESTRO_EXIT" -ne 0 ]; then
      printf '{"decision": "continue", "reason": "La suite de seguridad de Maestro (.maestro/tests/test_maestro_security_suite.py) falló (código %s). Corrige los fallos antes de finalizar."}\n' "$MAESTRO_EXIT"
      exit 0
    fi
    echo "[pre_stop_test] OK: Suite de seguridad de Maestro completada con éxito." >&2
  fi
fi

# 2. Si no hay cambios en Flutter, no ejecutar suite de Flutter
if [ -z "$HAS_FLUTTER_CHANGES" ]; then
  if [ -n "$HAS_MAESTRO_CHANGES" ]; then
    echo "[pre_stop_test] OK: Verificación de Maestro completada (sin cambios pendientes en código Flutter)." >&2
  else
    echo "[pre_stop_test] Omitido: no se detectaron cambios en archivos de Flutter ni de Maestro en esta sesión." >&2
  fi
  printf '{}\n'
  exit 0
fi

if ! command -v docker-compose >/dev/null 2>&1; then
  echo "[pre_stop_test] ERROR: 'docker-compose' no está disponible en PATH; no se ejecutaron pruebas." >&2
  printf '{"decision": "continue", "reason": "[pre_stop_test] No se ejecutaron pruebas porque docker-compose no está disponible. Nunca declares que las pruebas pasaron sin ejecutarlas."}\n'
  exit 0
fi

CONTAINER_ID=$(docker-compose ps -q flutter-env 2>/dev/null || true)
if [ -z "$CONTAINER_ID" ]; then
  echo "[pre_stop_test] ERROR: El servicio Docker 'flutter-env' no está en ejecución; no se ejecutaron pruebas." >&2
  printf '{"decision": "continue", "reason": "[pre_stop_test] No se ejecutaron pruebas porque el servicio Docker flutter-env no está activo (ejecuta make up). Nunca declares éxito sin ejecutar pruebas."}\n'
  exit 0
fi

TEST_EXIT=0
docker-compose exec -T flutter-env flutter test -j 1 >&2 || TEST_EXIT=$?

if [ "$TEST_EXIT" -ne 0 ]; then
  printf '{"decision": "continue", "reason": "docker-compose exec -T flutter-env flutter test -j 1 falló (código %s). Corrige las pruebas antes de finalizar."}\n' "$TEST_EXIT"
else
  echo "[pre_stop_test] OK: docker-compose exec -T flutter-env flutter test -j 1 completado con éxito." >&2
  printf '{}\n'
fi
