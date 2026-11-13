#!/usr/bin/env python3
"""Validador determinista de reglas y anti-fraude para moneo-transaction-classifier.

Uso:
    uv run .agents/skills/moneo-transaction-classifier/scripts/validate_classification.py --self-test
    uv run .agents/skills/moneo-transaction-classifier/scripts/validate_classification.py ruta/a/clasificacion.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

URGENCY_PATTERN = re.compile(
    r"(cuenta\s+bloqueada|suspensi[oó]n\s+inmediata|verifica\s+tu\s+identidad|"
    r"[uú]ltimo\s+aviso|actualiza\s+tus\s+datos|evita\s+el\s+bloqueo|"
    r"haz\s+clic|ingresa\s+aqu[ií]|acceso\s+suspendido)",
    re.IGNORECASE,
)
LINK_PATTERN = re.compile(
    r"(https?://\S+|www\.\S+|\b(?:bit\.ly|tinyurl\.com|t\.co|cutt\.ly|rb\.gy|wa\.me)/\S+)",
    re.IGNORECASE,
)

CLASSIFICATION_TO_MONEO = {
    "gasto": "Expenses",
    "ingreso": "Income",
    "transferencia-propia": "Transfer",
    "sospechosa": None,
}
VALID_SOURCES = {
    "anti_fraud",
    "learned_patterns",
    "deterministic_rules",
    "gemma_fallback",
    "fallback_ambiguous",
}


def has_fraud_signals(raw_text: str | None) -> bool:
    if not raw_text:
        return False
    return bool(LINK_PATTERN.search(raw_text) or URGENCY_PATTERN.search(raw_text))


def validate_classification(
    payload: dict[str, Any],
    *,
    raw_text: str | None = None,
    had_deterministic_match: bool = False,
) -> list[str]:
    errors: list[str] = []

    required = {
        "classification",
        "moneo_type",
        "category",
        "account_name",
        "destination_account",
        "confidence",
        "requires_review",
        "create_transaction",
        "decision_source",
    }
    missing = required - payload.keys()
    if missing:
        return [f"Faltan campos obligatorios: {sorted(missing)}"]

    classification = payload["classification"]
    moneo_type = payload["moneo_type"]
    create_tx = payload["create_transaction"]
    requires_review = payload["requires_review"]
    source = payload["decision_source"]
    confidence = payload["confidence"]

    if classification not in CLASSIFICATION_TO_MONEO:
        errors.append(f"classification inválida: {classification!r}")
    else:
        expected_moneo = CLASSIFICATION_TO_MONEO[classification]
        if moneo_type != expected_moneo:
            errors.append(
                f"Mapeo Moneo inconsistente: {classification!r} exige moneo_type={expected_moneo!r}, recibido {moneo_type!r}."
            )

    if source not in VALID_SOURCES:
        errors.append(f"decision_source inválido: {source!r}")

    if not isinstance(confidence, (int, float)) or not (0.0 <= float(confidence) <= 1.0):
        errors.append(f"confidence fuera de [0.0, 1.0]: {confidence!r}")

    # Regla anti-fraude estricta
    if has_fraud_signals(raw_text):
        if classification != "sospechosa":
            errors.append("Anti-fraude violado: texto con link o urgencia no clasificado como 'sospechosa'.")
        if create_tx is not False:
            errors.append("Anti-fraude violado: notificación fraudulenta intenta crear transacción.")

    if classification == "sospechosa":
        if create_tx is not False:
            errors.append("Invariante violado: 'sospechosa' nunca puede tener create_transaction=True.")
        if requires_review is not True:
            errors.append("Invariante violado: 'sospechosa' debe tener requires_review=True.")

    if classification == "transferencia-propia" and not payload.get("destination_account"):
        errors.append("Transferencia propia requiere destination_account no nulo.")

    if had_deterministic_match and source == "gemma_fallback":
        errors.append("Jerarquía violada: se invocó gemma_fallback aunque ya existía match determinista o en learned_patterns.")

    if requires_review is True and create_tx is True:
        errors.append("Invariante violado: una clasificación con requires_review=True no puede crear transacción automáticamente.")

    return errors


def _run_self_test() -> int:
    # 1. Caso válido determinista
    ok_case = {
        "classification": "gasto",
        "moneo_type": "Expenses",
        "category": "Alimentación",
        "account_name": "Nequi *1234",
        "destination_account": None,
        "confidence": 0.92,
        "requires_review": False,
        "create_transaction": True,
        "decision_source": "learned_patterns",
    }
    if errs := validate_classification(ok_case, raw_text="Pago en D1 por $32.000", had_deterministic_match=True):
        print(f"FAIL self-test (caso válido): {errs}", file=sys.stderr)
        return 1

    # 2. Caso que DEBE fallar: urgencia clasificada como gasto con create_transaction=True
    bad_urgency = {
        "classification": "gasto",
        "moneo_type": "Expenses",
        "category": "Otros",
        "account_name": "Ahorros",
        "destination_account": None,
        "confidence": 0.85,
        "requires_review": False,
        "create_transaction": True,
        "decision_source": "deterministic_rules",
    }
    if not validate_classification(
        bad_urgency,
        raw_text="URGENTE: Tu cuenta bloqueada sera suspendida, verifica tu identidad por $50.000",
    ):
        print("FAIL self-test: debía bloquear mensaje de urgencia.", file=sys.stderr)
        return 1

    # 3. Caso que DEBE fallar: Gemma usado cuando ya había match determinista
    bad_gemma = dict(ok_case, decision_source="gemma_fallback")
    if not validate_classification(bad_gemma, had_deterministic_match=True):
        print("FAIL self-test: debía rechazar gemma_fallback cuando hay match determinista.", file=sys.stderr)
        return 1

    print("OK: moneo-transaction-classifier self-test superado.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida la salida de moneo-transaction-classifier.")
    parser.add_argument("json_file", nargs="?", help="Ruta a archivo JSON con la clasificación.")
    parser.add_argument("--raw-text", help="Texto crudo opcional para validar señales de urgencia o links.")
    parser.add_argument("--deterministic-match", action="store_true", help="Indica si hubo match previo en reglas/learned_patterns.")
    parser.add_argument("--self-test", action="store_true", help="Ejecuta pruebas positivas y negativas.")
    args = parser.parse_args()

    if args.self_test:
        return _run_self_test()

    if not args.json_file:
        parser.print_help()
        return 2

    data = json.loads(Path(args.json_file).read_text(encoding="utf-8"))
    errors = validate_classification(
        data,
        raw_text=args.raw_text,
        had_deterministic_match=args.deterministic_match,
    )
    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    print("OK: clasificación válida.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
