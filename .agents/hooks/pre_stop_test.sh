#!/usr/bin/env sh
# Hook Stop: ejecuta `flutter test` antes de finalizar el agente (local o vía Docker finazaap-flutter).

PAYLOAD=$(cat)

SHOULD_SKIP=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("yes")
    sys.exit(0)
if d.get("continuationActive") is True:
    print("yes")
elif d.get("terminationReason") in ("USER_CANCELED", "ERROR"):
    print("yes")
else:
    print("no")
' 2>/dev/null)

if [ "$SHOULD_SKIP" = "yes" ]; then
  printf '{}\n'
  exit 0
fi

CWD=$(printf '%s' "$PAYLOAD" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("cwd",""))' 2>/dev/null)
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  cd "$CWD" || true
fi

TEST_EXIT=0
if command -v flutter >/dev/null 2>&1; then
  flutter test >&2 || TEST_EXIT=$?
elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^finazaap-flutter$'; then
  docker exec finazaap-flutter flutter test >&2 || TEST_EXIT=$?
fi

if [ "$TEST_EXIT" -ne 0 ]; then
  printf '{"decision": "continue", "reason": "flutter test falló (código %s). Corrige las pruebas antes de finalizar."}\n' "$TEST_EXIT"
else
  printf '{}\n'
fi
