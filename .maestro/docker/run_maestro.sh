#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAESTRO_ENV_DIR="${REPO_ROOT}/.maestro-env"

# Si corre dentro de un worktree, resolver el .maestro-env del repositorio principal
if [ ! -d "${MAESTRO_ENV_DIR}/maestro" ]; then
  GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$GIT_COMMON" ]; then
    MAIN_ROOT="$(cd "${GIT_COMMON}/.." 2>/dev/null && pwd)"
    if [ -d "${MAIN_ROOT}/.maestro-env/maestro" ]; then
      MAESTRO_ENV_DIR="${MAIN_ROOT}/.maestro-env"
    fi
  fi
fi

mkdir -p "${MAESTRO_ENV_DIR}/cache" "${MAESTRO_ENV_DIR}/evidence" "${MAESTRO_ENV_DIR}/home"

# Asegurar detección de Docker host en macOS / perfil local
if [ -z "${DOCKER_HOST:-}" ]; then
  if [ -S "/Users/jesusmartinez/.agys/profiles/karoll/.docker/run/docker.sock" ]; then
    export DOCKER_HOST="unix:///Users/jesusmartinez/.agys/profiles/karoll/.docker/run/docker.sock"
  elif [ -S "/var/run/docker.sock" ]; then
    export DOCKER_HOST="unix:///var/run/docker.sock"
  fi
fi

# 1. Validación estática previa de seguridad antes de cualquier interacción
VALIDATOR="${REPO_ROOT}/.maestro/docker/maestro_validator.py"
if [ ! -f "$VALIDATOR" ]; then
  VALIDATOR="$(dirname "${BASH_SOURCE[0]}")/maestro_validator.py"
fi
if [ -f "$VALIDATOR" ]; then
  python3 "$VALIDATOR" "$@"
fi

# 2. Control de concurrencia de dispositivo exclusivo (R5CY21GE9YY)
LOCK_FILE="${MAESTRO_ENV_DIR}/device_R5CY21GE9YY.lock"
if [ -f "$LOCK_FILE" ]; then
  EXISTING_PID=$(python3 -c "import json, sys; d=json.load(open('$LOCK_FILE')); print(d.get('pid',''))" 2>/dev/null || cat "$LOCK_FILE" 2>/dev/null || true)
  if [ -n "$EXISTING_PID" ] && kill -0 "$EXISTING_PID" 2>/dev/null; then
    echo "[BLOQUEO DE DISPOSITIVO] Dispositivo R5CY21GE9YY está actualmente reservado por proceso PID ${EXISTING_PID}." >&2
    echo "No se permite concurrencia de automatización en el mismo dispositivo." >&2
    exit 2
  else
    echo "[AVISO] Limpiando lock huérfano de dispositivo previo (PID ${EXISTING_PID} inactivo)." >&2
    rm -f "$LOCK_FILE"
  fi
fi

if [ ! -x "${MAESTRO_ENV_DIR}/maestro/bin/maestro" ]; then
  echo "ERROR: Maestro binary not found at ${MAESTRO_ENV_DIR}/maestro/bin/maestro" >&2
  exit 1
fi

# Registrar reserva exclusiva de dispositivo con el PID del shell principal ($$)
python3 -c "
import json, time, os, sys
data = {
    'pid': int(sys.argv[1]),
    'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    'device': 'R5CY21GE9YY',
    'appId': 'com.example.finazaap.validation',
    'args': sys.argv[2:]
}
with open('$LOCK_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" "$$" "$@"

cleanup_lock() {
  # Liberar lock solo si pertenece a este PID
  if [ -f "$LOCK_FILE" ]; then
    MY_PID=$$
    LOCK_PID=$(python3 -c "import json, sys; d=json.load(open('$LOCK_FILE')); print(d.get('pid',''))" 2>/dev/null || true)
    if [ "$LOCK_PID" = "$MY_PID" ]; then
      rm -f "$LOCK_FILE"
    fi
  fi
}
trap cleanup_lock EXIT INT TERM HUP

# 3. Ejecución dentro del contenedor dedicado finazaap-maestro con aislamiento de red
docker run --rm \
  --name "finazaap-maestro-run-$$" \
  --cap-add=NET_ADMIN \
  -v "${REPO_ROOT}:/workspace" \
  -v "${MAESTRO_ENV_DIR}:/maestro-env" \
  -e HOME=/maestro-env/home \
  -e MAESTRO_CLI_NO_ANALYTICS=true \
  -e MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true \
  -e ANDROID_ADB_SERVER_ADDRESS=host.docker.internal \
  -e ANDROID_ADB_SERVER_PORT=5037 \
  finazaap-maestro:local \
  bash -c '
    set -euo pipefail
    HOST_IP=$(getent hosts host.docker.internal | awk "{print \$1}" | head -n 1)
    if [ -z "$HOST_IP" ]; then
      echo "ERROR: Could not resolve host.docker.internal" >&2
      exit 1
    fi
    # Bloquear todo tráfico saliente excepto loopback, conexiones establecidas y host ADB (puerto 5037)
    iptables -F OUTPUT
    iptables -P OUTPUT DROP
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport 5037 -j ACCEPT
    iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport 7001 -j ACCEPT
    python3 /workspace/.maestro/docker/adb_loopback_bridge.py "$HOST_IP" &
    BRIDGE_PID=$!
    trap "kill $BRIDGE_PID 2>/dev/null || true" EXIT
    sleep 0.3
    unset ANDROID_ADB_SERVER_ADDRESS ANDROID_ADB_SERVER_PORT
    exec maestro --device R5CY21GE9YY "$@"
  ' -- "$@"
