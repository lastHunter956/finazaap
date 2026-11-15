#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAESTRO_ENV_DIR="${REPO_ROOT}/.maestro-env"
mkdir -p "${MAESTRO_ENV_DIR}/cache" "${MAESTRO_ENV_DIR}/evidence" "${MAESTRO_ENV_DIR}/home"

if [ ! -x "${MAESTRO_ENV_DIR}/maestro/bin/maestro" ]; then
  echo "ERROR: Maestro binary not found at ${MAESTRO_ENV_DIR}/maestro/bin/maestro" >&2
  exit 1
fi

# Run inside dedicated container with outbound internet blocked except loopback and host ADB (port 5037)
docker run --rm \
  --name finazaap-maestro-run \
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
    # Block all outbound traffic except loopback, established, and host ADB/driver ports
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
    exec "$@"
  ' -- "$@"
