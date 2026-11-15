#!/usr/bin/env python3
"""Validador estático previo para ejecuciones de Maestro en Moneo.

Garantiza:
1. Dispositivo exclusivo: R5CY21GE9YY.
2. Aplicación autorizada única: com.example.finazaap.validation (protege com.example.finazaap).
3. Rechazo de acciones destructivas: clearState: true, uninstallApp, installApp, clearKeychain.
4. Rechazo de funciones remotas y telemetría: maestro cloud, login, logout, assertWithAI.
5. Control de scripts y subflujos recursivos.
"""

import os
import re
import sys
from typing import Any, List, Set

AUTHORIZED_DEVICE = "R5CY21GE9YY"
AUTHORIZED_APP_ID = "com.example.finazaap.validation"
PROTECTED_APP_ID = "com.example.finazaap"

BLOCKED_SUBCOMMANDS = {
    "cloud",
    "login",
    "logout",
    "download-samples",
    "start-device",
    "list-cloud-devices",
}

BLOCKED_FLOW_COMMANDS = {
    "assertWithAI",
    "clearKeychain",
    "uninstallApp",
    "installApp",
    "openLink",
}


class ValidationError(Exception):
    """Error de validación de seguridad de Maestro."""


def check_cli_args(args: List[str]) -> List[str]:
    """Valida los argumentos del comando CLI de Maestro."""
    if not args:
        return []

    # Extraer subcomando y opciones
    subcmd = None
    flow_files: List[str] = []
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in BLOCKED_SUBCOMMANDS:
            raise ValidationError(
                f"[Seguridad Maestro] Subcomando bloqueado '{arg}'. Maestro Cloud y funciones remotas están prohibidas."
            )

        if arg == "record":
            # Verificar que incluya --local
            if "--local" not in args and "-l" not in args:
                raise ValidationError(
                    "[Seguridad Maestro] 'maestro record' requiere obligatoriamente '--local' para evitar subidas remotas."
                )

        if arg in ("--device", "--udid", "-d") and i + 1 < len(args):
            dev = args[i + 1]
            if dev != AUTHORIZED_DEVICE:
                raise ValidationError(
                    f"[Seguridad Maestro] Dispositivo '{dev}' no autorizado. El único dispositivo autorizado es '{AUTHORIZED_DEVICE}'."
                )
            i += 2
            continue
        elif arg.startswith("--device=") or arg.startswith("--udid="):
            dev = arg.split("=", 1)[1]
            if dev != AUTHORIZED_DEVICE:
                raise ValidationError(
                    f"[Seguridad Maestro] Dispositivo '{dev}' no autorizado. El único dispositivo autorizado es '{AUTHORIZED_DEVICE}'."
                )
            i += 1
            continue

        if subcmd is None and not arg.startswith("-"):
            subcmd = arg
        elif subcmd == "test" and not arg.startswith("-"):
            flow_files.append(arg)
        elif subcmd == "hierarchy":
            pass

        i += 1

    return flow_files


def inspect_yaml_content(content: str, file_path: str, visited_files: Set[str]) -> None:
    """Inspecciona el contenido YAML de un flujo de Maestro."""
    # Verificar appId a nivel global en el flujo
    app_id_matches = re.findall(r"^\s*appId:\s*(\S+)", content, re.MULTILINE)
    for app in app_id_matches:
        clean_app = app.strip("'\"")
        if clean_app == PROTECTED_APP_ID:
            raise ValidationError(
                f"[Seguridad Maestro] Infracción crítica en '{file_path}': intenta acceder a la aplicación productiva protegida '{PROTECTED_APP_ID}'."
            )
        if clean_app != AUTHORIZED_APP_ID:
            raise ValidationError(
                f"[Seguridad Maestro] Infracción en '{file_path}': appId '{clean_app}' no autorizado. Solo se permite '{AUTHORIZED_APP_ID}'."
            )

    # Verificar presencia obligatoria de appId si el flujo interactúa con la app
    if not app_id_matches and ("launchApp" in content or "stopApp" in content):
        raise ValidationError(
            f"[Seguridad Maestro] El flujo '{file_path}' carece de declaración explícita de appId ('{AUTHORIZED_APP_ID}')."
        )

    # Verificar comandos destructivos y no autorizados
    for blocked_cmd in BLOCKED_FLOW_COMMANDS:
        pattern = rf"(?:^|\s|-)\s*{re.escape(blocked_cmd)}\b"
        if re.search(pattern, content, re.MULTILINE):
            raise ValidationError(
                f"[Seguridad Maestro] Comando prohibido '{blocked_cmd}' detectado en '{file_path}'."
            )

    # Verificar clearState: true (destrucción de datos)
    if re.search(r"clearState:\s*true\b", content, re.IGNORECASE):
        raise ValidationError(
            f"[Seguridad Maestro] Acción destructiva 'clearState: true' detectada en '{file_path}'. Prohibido limpiar datos de la app."
        )

    # Verificar scripts arbitrarios
    if re.search(r"(?:^|\s|-)\s*runScript:\s*(\S+)", content, re.MULTILINE):
        raise ValidationError(
            f"[Seguridad Maestro] 'runScript' detectado en '{file_path}'. La ejecución de scripts arbitrarios en flujos no está autorizada."
        )

    # Verificar subflujos recursivos (runFlow)
    run_flow_matches = re.findall(r"(?:^|\s|-)\s*runFlow:\s*(?:file:\s*)?([^\n\r]+)", content, re.MULTILINE)
    base_dir = os.path.dirname(os.path.abspath(file_path))
    for subflow in run_flow_matches:
        subflow_clean = subflow.strip().strip("'\"")
        # Quitar parámetros o llaves si vienen en formato objeto
        if "{" in subflow_clean:
            m = re.search(r"file:\s*([^\s,}]+)", subflow_clean)
            if m:
                subflow_clean = m.group(1).strip("'\"")
            else:
                continue

        subflow_path = os.path.normpath(os.path.join(base_dir, subflow_clean)) if not os.path.isabs(subflow_clean) else subflow_clean
        validate_flow_file(subflow_path, visited_files)


def validate_flow_file(file_path: str, visited_files: Set[str]) -> None:
    """Valida un archivo de flujo y sus dependencias."""
    abs_path = os.path.abspath(file_path)
    if abs_path in visited_files:
        return
    visited_files.add(abs_path)

    if not os.path.isfile(abs_path):
        raise ValidationError(f"[Seguridad Maestro] Archivo de flujo no encontrado: '{file_path}'")

    try:
        with open(abs_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        raise ValidationError(f"[Seguridad Maestro] Error al leer archivo '{file_path}': {e}")

    inspect_yaml_content(content, file_path, visited_files)


def validate_maestro_execution(argv: List[str]) -> int:
    """Función principal de validación de ejecución de Maestro."""
    try:
        flow_files = check_cli_args(argv)
        visited: Set[str] = set()
        for f in flow_files:
            if os.path.isdir(f):
                for root, _, files in os.walk(f):
                    for fn in files:
                        if fn.endswith((".yaml", ".yml")):
                            validate_flow_file(os.path.join(root, fn), visited)
            else:
                validate_flow_file(f, visited)
        return 0
    except ValidationError as ve:
        print(str(ve), file=sys.stderr)
        return 1
    except Exception as ex:
        print(f"[Seguridad Maestro] Error inesperado en validación: {ex}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(validate_maestro_execution(sys.argv[1:]))
