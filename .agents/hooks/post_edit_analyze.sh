#!/usr/bin/env sh
# Hook PostToolUse: ejecuta `dart analyze` tras editar archivos (local o vía Docker finazaap-flutter).

PAYLOAD=$(cat)
CWD=$(printf '%s' "$PAYLOAD" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("cwd",""))' 2>/dev/null)

if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  cd "$CWD" || true
fi

if command -v dart >/dev/null 2>&1; then
  dart analyze >&2 || true
elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^finazaap-flutter$'; then
  docker exec finazaap-flutter dart analyze >&2 || true
fi

printf '{}\n'
