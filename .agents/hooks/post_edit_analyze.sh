#!/usr/bin/env sh
# Hook PostToolUse: ejecuta `docker-compose exec -T flutter-env dart analyze` solo tras editar archivos Dart/Pub/Analysis.

PAYLOAD=$(cat)
PARSED=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("|")
    sys.exit(0)
cwd = str(d.get("cwd") or "")
args = (d.get("toolCall") or {}).get("args") or {}
fpath = str(args.get("Path") or args.get("path") or args.get("AbsolutePath") or args.get("TargetFile") or "")
print(f"{cwd}|{fpath}")
' 2>/dev/null)

CWD=$(printf '%s' "$PARSED" | cut -d'|' -f1)
FPATH=$(printf '%s' "$PARSED" | cut -d'|' -f2-)

case "$FPATH" in
  *.dart|*pubspec.yaml|*analysis_options.yaml)
    ;;
  *)
    printf '{}\n'
    exit 0
    ;;
esac

if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  cd "$CWD" || true
fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || true

if command -v docker-compose >/dev/null 2>&1 && [ -n "$(docker-compose ps -q flutter-env 2>/dev/null)" ]; then
  docker-compose exec -T flutter-env dart analyze >&2 || true
else
  echo "[post_edit_analyze] Omitido con motivo: servicio Docker 'flutter-env' no disponible para ejecutar dart analyze." >&2
fi

printf '{}\n'
