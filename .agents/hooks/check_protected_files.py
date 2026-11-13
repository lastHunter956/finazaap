#!/usr/bin/env python3
"""Hook PreToolUse: verifica que write_file/edit_file no modifiquen archivos protegidos sin aprobación."""

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
        print(json.dumps({"decision": "allow"}))
        return

    args = payload.get("toolCall", {}).get("args", {})
    raw_path = args.get("Path") or args.get("path") or ""
    cwd = payload.get("cwd") or os.getcwd()

    if not raw_path:
        print(json.dumps({"decision": "allow"}))
        return

    abs_target = os.path.abspath(raw_path)
    abs_cwd = os.path.abspath(cwd)
    try:
        rel_path = os.path.relpath(abs_target, abs_cwd).replace(os.sep, "/")
    except ValueError:
        rel_path = raw_path.replace(os.sep, "/")

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
