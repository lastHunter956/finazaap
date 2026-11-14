#!/usr/bin/env python3
"""Hook PreToolUse: protección principal del repositorio (fail-closed) para secretos, teléfono, Git, red, archivos protegidos y migraciones."""

import fnmatch
import json
import os
import re
import sys

FILE_TOOLS = {
    "read_file",
    "view_file",
    "write_file",
    "write_to_file",
    "edit_file",
    "replace_file_content",
    "multi_replace_file_content",
}

WRITE_TOOLS = {
    "write_file",
    "write_to_file",
    "edit_file",
    "replace_file_content",
    "multi_replace_file_content",
}

COMMAND_TOOLS = {"run_command", "shell_exec"}

ALLOWED_ENV_TEMPLATES = {
    ".env.example",
    ".env.template",
    ".env.sample",
}

SECRET_EXACT_NAMES = {
    ".env",
    "key.properties",
    "google-services.json",
    "googleservice-info.plist",
}

SECRET_EXTENSIONS = (".jks", ".keystore", ".p12", ".pfx", ".pem", ".key")

PROTECTED_PATTERNS = (
    "lib/data/transaction_service.dart",
    "lib/data/credit_card_calculator.dart",
    "lib/data/model/*.g.dart",
    "android/app/build.gradle",
    "android/app/src/main/AndroidManifest.xml",
    "lib/core/security/*",
    "lib/core/security/**",
)

PROTECTED_PATH_MARKERS = (
    "lib/data/transaction_service.dart",
    "lib/data/credit_card_calculator.dart",
    "android/app/build.gradle",
    "android/app/src/main/androidmanifest.xml",
    "lib/core/security/",
    ".g.dart",
)

PHONE_DESTRUCTIVE_RE = re.compile(
    r"\b(?:adb\s+(?:-\S+\s+\S+\s+)?uninstall\b"
    r"|adb\s+(?:-\S+\s+\S+\s+)?shell\s+(?:['\"])?pm\s+clear\b"
    r"|adb\s+(?:-\S+\s+\S+\s+)?shell\s+(?:['\"])?am\s+force-stop\b"
    r"|adb\s+(?:-\S+\s+\S+\s+)?install\b[^\n]*\s-d(?:\s|$)"
    r"|adb\s+(?:-\S+\s+\S+\s+)?shell\s+(?:['\"])?rm\b[^\n]*(?:/data/data/|/sdcard/|finazaap|moneo))",
    re.IGNORECASE,
)

PHONE_INSTALL_RE = re.compile(
    r"\b(?:adb\s+(?:-\S+\s+\S+\s+)?install\b|flutter\s+install\b)",
    re.IGNORECASE,
)

NETWORK_CMD_RE = re.compile(r"\b(?:curl|wget|nc|ncat|scp|rsync)\b", re.IGNORECASE)
NETWORK_UPLOAD_RE = re.compile(
    r"(?:\s(?:-d|--data|--data-raw|--data-binary|-F|--form|-T|--upload-file)\b|\b(?:POST|PUT|PATCH)\b|\b(?:scp|rsync)\b)",
    re.IGNORECASE,
)
SENSITIVE_PAYLOAD_RE = re.compile(
    r"(?:\.env(?:\.|$)|\.(?:jks|keystore|p12|pfx|pem|key|hive|db|sqlite)\b|key\.properties|google-services\.json|pending_notifications|learned_patterns|notification_text|raw_notification|financial|saldo|monto|token|secret|password|credential)",
    re.IGNORECASE,
)

SECRET_CMD_READ_RE = re.compile(
    r"(?:^|[;&|]\s*|\s)(?:cat|less|more|head|tail|sed|awk|grep|rg|cp|mv|scp|rsync|base64|xxd|strings|printenv|source|\.|python3?|sh|bash|zsh)\b",
    re.IGNORECASE,
)


def emit(decision: str, reason: str = "") -> None:
    out = {"decision": decision}
    if reason:
        out["reason"] = reason
    print(json.dumps(out))


def is_secret_path(raw_path: str) -> bool:
    norm = raw_path.strip().strip("'\"").replace("\\", "/")
    base = os.path.basename(norm).lower()
    if not base:
        return False
    if base in ALLOWED_ENV_TEMPLATES:
        return False
    if base in SECRET_EXACT_NAMES or base.startswith(".env."):
        return True
    if base.endswith(SECRET_EXTENSIONS):
        return True
    if ("credential" in base or "secret" in base) and base.endswith(
        (".json", ".yaml", ".yml", ".txt", ".plist", ".env")
    ):
        return True
    return False


def is_protected_rel_path(rel_path: str) -> bool:
    norm = rel_path.strip().replace("\\", "/").lstrip("./")
    for pattern in PROTECTED_PATTERNS:
        if fnmatch.fnmatch(norm, pattern) or norm.startswith("lib/core/security/"):
            return True
    return False


def resolve_rel_path(raw_path: str, cwd: str) -> str:
    clean = raw_path.strip().strip("'\"")
    abs_target = os.path.abspath(os.path.join(cwd, clean) if not os.path.isabs(clean) else clean)
    abs_cwd = os.path.abspath(cwd)
    try:
        rel = os.path.relpath(abs_target, abs_cwd).replace(os.sep, "/")
        if not rel.startswith(".."):
            return rel
    except ValueError:
        pass
    return clean.replace("\\", "/")


def check_file_tool(tool_name: str, args: dict, cwd: str) -> None:
    raw_path = (
        args.get("Path")
        or args.get("path")
        or args.get("AbsolutePath")
        or args.get("TargetFile")
        or ""
    )
    if not isinstance(raw_path, str) or not raw_path.strip():
        emit(
            "deny",
            f"[Regla: Guardián] Llamada a {tool_name} sin ruta válida (fail-closed).",
        )
        return

    if is_secret_path(raw_path):
        emit(
            "deny",
            f"[Regla: Secretos] Acceso denegado a '{raw_path}' en {tool_name}. Solo se permiten plantillas sin secretos como .env.example.",
        )
        return

    if tool_name in WRITE_TOOLS:
        norm_raw = raw_path.strip().strip("'\"").replace("\\", "/")
        if norm_raw == ".git" or norm_raw.startswith(".git/") or "/.git/" in norm_raw or norm_raw.endswith("/.git"):
            emit(
                "deny",
                f"[Regla: Git] Escritura directa denegada sobre directorio interno '.git' ('{raw_path}').",
            )
            return
        rel_path = resolve_rel_path(raw_path, cwd)
        if is_protected_rel_path(rel_path):
            emit(
                "force_ask",
                f"[Regla: Archivos Protegidos] '{rel_path}' es un archivo crítico protegido y requiere aprobación explícita del usuario.",
            )
            return

    emit("allow")


def command_references_secret_file(cmd: str) -> str | None:
    tokens = re.findall(r"""['"]?([^\s'"|;&><=()]+)['"]?""", cmd)
    for tok in tokens:
        if is_secret_path(tok):
            return tok
    return None


def check_run_command(tool_name: str, args: dict) -> None:
    cmd = args.get("CommandLine") or args.get("command") or ""
    if not isinstance(cmd, str) or not cmd.strip():
        emit(
            "deny",
            f"[Regla: Guardián] Llamada a {tool_name} sin CommandLine válido (fail-closed).",
        )
        return
    cmd = cmd.strip()

    if PHONE_DESTRUCTIVE_RE.search(cmd):
        emit(
            "deny",
            "[Regla: Teléfono/ADB] Comando destructivo bloqueado (uninstall, pm clear, force-stop, downgrade -d o borrado de datos).",
        )
        return

    secret_tok = command_references_secret_file(cmd)
    if secret_tok and SECRET_CMD_READ_RE.search(cmd):
        emit(
            "deny",
            f"[Regla: Secretos] Acceso bloqueado a archivo sensible '{secret_tok}' desde {tool_name}.",
        )
        return

    if NETWORK_CMD_RE.search(cmd):
        if secret_tok or (NETWORK_UPLOAD_RE.search(cmd) and SENSITIVE_PAYLOAD_RE.search(cmd)):
            emit(
                "deny",
                "[Regla: Red/Privacidad] Bloqueado envío de secretos, contenido de notificaciones o datos financieros fuera del dispositivo.",
            )
            return
        if SENSITIVE_PAYLOAD_RE.search(cmd):
            emit(
                "force_ask",
                "[Regla: Red/Privacidad] Comando de red menciona datos financieros, notificaciones, credenciales o rutas privadas. Requiere aprobación explícita.",
            )
            return

    if PHONE_INSTALL_RE.search(cmd):
        emit(
            "force_ask",
            "[Regla: Teléfono/Instalación] Requiere aprobación explícita. Antes de instalar, muestra: commit, ruta y SHA-256 del APK, dispositivo, applicationId, versionCode, versionName, firma/certificado y confirmación de preservación de datos.",
        )
        return

    if re.search(r"\bgit\s+(?:push|merge|rebase)\b", cmd):
        if re.search(r"\bgit\s+(?:push|merge|rebase)\b[^\n]*\bmain\b", cmd):
            emit(
                "force_ask",
                "[Regla: Git/main] Operación sobre 'main' (merge/rebase/push) requiere aprobación explícita obligatoria.",
            )
            return
        emit(
            "force_ask",
            "[Regla: Git] git merge / rebase / push requiere confirmación explícita (verifica rama de integración y que no afecte ramas ajenas).",
        )
        return

    cmd_lower = cmd.lower()
    if "build_runner" in cmd_lower:
        emit(
            "force_ask",
            "[Regla: Archivos Protegidos] build_runner regenera adaptadores Hive (*.g.dart) y requiere aprobación explícita.",
        )
        return
    if re.search(r"(?:>|>>|\b(?:tee|cp|mv|rm|sed\s+-i|python3?\s+-c)\b)", cmd):
        for marker in PROTECTED_PATH_MARKERS:
            if marker in cmd_lower:
                emit(
                    "force_ask",
                    f"[Regla: Archivos Protegidos] Posible modificación de archivo protegido ('{marker}') vía shell. Requiere aprobación explícita.",
                )
                return

    if re.search(r"\b(?:migrat(?:e|ion)|schema_version)\b", cmd_lower):
        emit(
            "force_ask",
            "[Regla: Migraciones] Ejecución relacionada con migración de datos/esquema requiere aprobación explícita.",
        )
        return

    emit("allow")


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        emit("deny", "[Regla: Guardián] Payload JSON inválido en PreToolUse (fail-closed).")
        return

    if not isinstance(payload, dict):
        emit("deny", "[Regla: Guardián] Payload PreToolUse no es un objeto JSON (fail-closed).")
        return

    tool_call = payload.get("toolCall")
    if not isinstance(tool_call, dict):
        emit("deny", "[Regla: Guardián] Campo 'toolCall' ausente o inválido (fail-closed).")
        return

    tool_name = tool_call.get("name") or ""
    args = tool_call.get("args")
    cwd = payload.get("cwd") or os.getcwd()

    if not isinstance(args, dict):
        emit("deny", f"[Regla: Guardián] Campo 'toolCall.args' inválido para '{tool_name}' (fail-closed).")
        return

    if tool_name in FILE_TOOLS:
        check_file_tool(tool_name, args, cwd)
    elif tool_name in COMMAND_TOOLS:
        check_run_command(tool_name, args)
    else:
        emit("force_ask", f"[Regla: Guardián] Herramienta '{tool_name}' no reconocida en matcher de seguridad (fail-closed).")


if __name__ == "__main__":
    main()
