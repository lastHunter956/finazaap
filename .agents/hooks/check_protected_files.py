#!/usr/bin/env python3
"""Hook PreToolUse: verifica que herramientas de edición no modifiquen archivos protegidos sin aprobación (fail-closed)."""

import fnmatch
import json
import os
import sys

PROTECTED_PATTERNS = [
    "lib/data/transaction_service.dart",
    "lib/data/credit_card_calculator.dart",
    "lib/data/model/*.g.dart",
    "android/app/build.gradle",
    "android/app/src/main/AndroidManifest.xml",
    "lib/core/security/*",
    "lib/core/security/**",
]


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        print(json.dumps({"decision": "deny", "reason": "Payload JSON inválido en check_protected_files.py (fail-closed)."}))
        return

    if not isinstance(payload, dict):
        print(json.dumps({"decision": "deny", "reason": "Payload inválido en check_protected_files.py (fail-closed)."}))
        return

    args = payload.get("toolCall", {}).get("args", {})
    if not isinstance(args, dict):
        print(json.dumps({"decision": "deny", "reason": "Argumentos inválidos en check_protected_files.py (fail-closed)."}))
        return

    raw_path = (
        args.get("Path")
        or args.get("path")
        or args.get("AbsolutePath")
        or args.get("TargetFile")
        or ""
    )
    cwd = payload.get("cwd") or os.getcwd()

    if not isinstance(raw_path, str) or not raw_path.strip():
        print(json.dumps({"decision": "deny", "reason": "Ruta de archivo vacía en check_protected_files.py (fail-closed)."}))
        return

    clean_path = raw_path.strip().strip("'\"")
    abs_target = os.path.abspath(os.path.join(cwd, clean_path) if not os.path.isabs(clean_path) else clean_path)
    abs_cwd = os.path.abspath(cwd)
    try:
        rel_path = os.path.relpath(abs_target, abs_cwd).replace(os.sep, "/")
    except ValueError:
        rel_path = clean_path.replace(os.sep, "/")

    for pattern in PROTECTED_PATTERNS:
        if fnmatch.fnmatch(rel_path, pattern) or rel_path.startswith("lib/core/security/"):
            print(
                json.dumps(
                    {
                        "decision": "force_ask",
                        "reason": (
                            f"Archivo protegido: {rel_path}. "
                            "Requiere aprobación explícita del usuario antes de modificarse."
                        ),
                    }
                )
            )
            return

    print(json.dumps({"decision": "allow"}))


if __name__ == "__main__":
    main()
