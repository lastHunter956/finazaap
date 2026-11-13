#!/usr/bin/env python3
"""Validador determinista de salida y reglas anti-fraude para moneo-notification-parser.

Uso:
    uv run .agents/skills/moneo-notification-parser/scripts/validate_parser_output.py --self-test
    uv run .agents/skills/moneo-notification-parser/scripts/validate_parser_output.py ruta/a/salida.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

LINK_PATTERN = re.compile(
    r"(https?://\S+|www\.\S+|\b(?:bit\.ly|tinyurl\.com|t\.co|cutt\.ly|rb\.gy|wa\.me)/\S+)",
    re.IGNORECASE,
)

VALID_STATUSES = {"parsed", "sospechosa", "unparseable"}
VALID_TIPOS = {"gasto", "ingreso", "transferencia", "desconocido", "sospechosa"}


def contains_suspicious_link(raw_text: str) -> bool:
    return bool(LINK_PATTERN.search(raw_text or ""))


def validate_parser_payload(payload: dict[str, Any], raw_text: str | None = None) -> list[str]:
    errors: list[str] = []

    required_keys = {
        "status",
        "tipo",
        "monto",
        "comercio",
        "fecha",
        "cuenta",
        "confidence",
        "requires_review",
        "auto_processable",
    }
    missing = required_keys - payload.keys()
    if missing:
        errors.append(f"Faltan campos obligatorios: {sorted(missing)}")
        return errors

    status = payload["status"]
    tipo = payload["tipo"]
    monto = payload["monto"]
    confidence = payload["confidence"]
    requires_review = payload["requires_review"]
    auto_processable = payload["auto_processable"]

    if status not in VALID_STATUSES:
        errors.append(f"status inválido: {status!r}")
    if tipo not in VALID_TIPOS:
        errors.append(f"tipo inválido: {tipo!r}")

    if not isinstance(confidence, (int, float)) or not (0.0 <= float(confidence) <= 1.0):
        errors.append(f"confidence debe estar en [0.0, 1.0], recibido: {confidence!r}")
    if not isinstance(requires_review, bool):
        errors.append(f"requires_review debe ser bool, recibido: {requires_review!r}")
    if not isinstance(auto_processable, bool):
        errors.append(f"auto_processable debe ser bool, recibido: {auto_processable!r}")

    # Regla anti-fraude: si el texto original tiene link, DEBE ser sospechosa y NO auto-procesable.
    if raw_text is not None and contains_suspicious_link(raw_text):
        if status != "sospechosa" or tipo != "sospechosa":
            errors.append("Anti-fraude violado: el texto contiene un link pero no fue marcado como 'sospechosa'.")
        if auto_processable is not False:
            errors.append("Anti-fraude violado: notificación con link tiene auto_processable=True.")

    if status == "sospechosa":
        if tipo != "sospechosa":
            errors.append("Invariante violado: status=='sospechosa' exige tipo=='sospechosa'.")
        if auto_processable is not False:
            errors.append("Invariante violado: status=='sospechosa' exige auto_processable=False.")
        if requires_review is not True:
            errors.append("Invariante violado: status=='sospechosa' exige requires_review=True.")
        if float(confidence) != 0.0:
            errors.append("Invariante violado: status=='sospechosa' exige confidence==0.0.")

    if status == "parsed":
        if monto is None or not isinstance(monto, (int, float)) or float(monto) <= 0:
            errors.append(f"status=='parsed' exige monto > 0, recibido: {monto!r}")

    if (monto is None or (isinstance(monto, (int, float)) and float(monto) <= 0)) and requires_review is not True:
        errors.append("Invariante violado: monto nulo o <= 0 exige requires_review=True.")

    if isinstance(confidence, (int, float)) and float(confidence) < 0.80 and requires_review is not True:
        errors.append("Invariante violado: confidence < 0.80 exige requires_review=True.")

    if requires_review is True and auto_processable is not False:
        errors.append("Invariante violado: requires_review=True exige auto_processable=False.")

    return errors


def _run_self_test() -> int:
    # 1. Caso válido: gasto claro en COP
    valid_case = {
        "status": "parsed",
        "tipo": "gasto",
        "monto": 45000.0,
        "moneda": "COP",
        "comercio": "Éxito Laureles",
        "fecha": "2026-11-13T14:30:00-05:00",
        "cuenta": {"last4": "4821", "hint": "ahorros"},
        "confidence": 0.93,
        "requires_review": False,
        "auto_processable": True,
        "flags": [],
    }
    errs = validate_parser_payload(valid_case, "Compra aprobada por $45.000 en Exito Laureles con cta *4821")
    if errs:
        print(f"FAIL self-test (caso válido): {errs}", file=sys.stderr)
        return 1

    # 2. Caso que DEBE fallar: texto con link marcado como parsed/auto_processable
    bad_phishing_case = {
        "status": "parsed",
        "tipo": "gasto",
        "monto": 100000.0,
        "comercio": "Banco",
        "fecha": "2026-11-13T14:30:00-05:00",
        "cuenta": {"last4": None, "hint": None},
        "confidence": 0.90,
        "requires_review": False,
        "auto_processable": True,
    }
    errs_phishing = validate_parser_payload(
        bad_phishing_case,
        "Compra por $100.000. Si no fuiste tu ingresa a https://bit.ly/3xFake",
    )
    if not errs_phishing:
        print("FAIL self-test: debía rechazar phishing con link.", file=sys.stderr)
        return 1

    # 3. Caso que DEBE fallar: baja confianza sin requires_review=True
    bad_confidence_case = {
        "status": "parsed",
        "tipo": "gasto",
        "monto": 1234.0,
        "comercio": None,
        "fecha": "2026-11-13T14:30:00-05:00",
        "cuenta": {"last4": None, "hint": None},
        "confidence": 0.55,
        "requires_review": False,
        "auto_processable": False,
    }
    if not validate_parser_payload(bad_confidence_case):
        print("FAIL self-test: debía rechazar confidence < 0.80 con requires_review=False.", file=sys.stderr)
        return 1

    print("OK: moneo-notification-parser self-test superado (contratos y anti-fraude verificados).")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida la salida JSON de moneo-notification-parser.")
    parser.add_argument("json_file", nargs="?", help="Ruta a archivo JSON con la salida del parser.")
    parser.add_argument("--raw-text", help="Texto crudo opcional para verificar detección anti-fraude de links.")
    parser.add_argument("--self-test", action="store_true", help="Ejecuta pruebas de contrato positivas y negativas.")
    args = parser.parse_args()

    if args.self_test:
        return _run_self_test()

    if not args.json_file:
        parser.print_help()
        return 2

    data = json.loads(Path(args.json_file).read_text(encoding="utf-8"))
    errors = validate_parser_payload(data, args.raw_text)
    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    print("OK: salida de parser válida.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
