#!/usr/bin/env python3
"""Validador determinista de invariantes para moneo-feedback-loop.

Uso:
    uv run .agents/skills/moneo-feedback-loop/scripts/verify_feedback_invariants.py --self-test
    uv run .agents/skills/moneo-feedback-loop/scripts/verify_feedback_invariants.py ruta/a/batch.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

HIGH_CONFIDENCE_THRESHOLD = 0.85


def is_eligible_for_accept_all(item: dict[str, Any]) -> bool:
    if item.get("classification") == "sospechosa":
        return False
    if item.get("requires_review") is not False:
        return False
    confidence = item.get("confidence", 0.0)
    if not isinstance(confidence, (int, float)) or float(confidence) < HIGH_CONFIDENCE_THRESHOLD:
        return False
    if not item.get("account_name"):
        return False
    if item.get("classification") == "transferencia-propia" and not item.get("destination_account"):
        return False
    return True


def simulate_accept_all(pending: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    accepted = [item for item in pending if is_eligible_for_accept_all(item)]
    remaining = [item for item in pending if not is_eligible_for_accept_all(item)]
    return accepted, remaining


def validate_batch_result(
    pending_before: list[dict[str, Any]],
    accepted: list[dict[str, Any]],
    remaining: list[dict[str, Any]],
    learned_patterns_updates: list[dict[str, Any]],
) -> list[str]:
    errors: list[str] = []

    for item in accepted:
        if not is_eligible_for_accept_all(item):
            errors.append(
                f"Invariante violado: 'aceptar todo' aceptó ítem no elegible id={item.get('id')!r} "
                f"(classification={item.get('classification')!r}, confidence={item.get('confidence')!r}, "
                f"requires_review={item.get('requires_review')!r})."
            )

    expected_accepted, expected_remaining = simulate_accept_all(pending_before)
    accepted_ids = {i.get("id") for i in accepted}
    expected_accepted_ids = {i.get("id") for i in expected_accepted}
    remaining_ids = {i.get("id") for i in remaining}
    expected_remaining_ids = {i.get("id") for i in expected_remaining}

    if accepted_ids != expected_accepted_ids:
        errors.append(f"Conjunto aceptado incorrecto: {accepted_ids} != esperado {expected_accepted_ids}")
    if remaining_ids != expected_remaining_ids:
        errors.append(f"Conjunto restante incorrecto: {remaining_ids} != esperado {expected_remaining_ids}")

    updated_merchants = {u.get("merchant_key") for u in learned_patterns_updates}
    for item in accepted:
        mkey = item.get("merchant_key")
        if mkey and mkey not in updated_merchants:
            errors.append(f"Falta actualización en learned_patterns para comercio aceptado {mkey!r}.")

    return errors


def _run_self_test() -> int:
    pending = [
        {
            "id": "1",
            "merchant_key": "exito laureles",
            "classification": "gasto",
            "category": "Alimentación",
            "account_name": "Ahorros *4821",
            "destination_account": None,
            "confidence": 0.94,
            "requires_review": False,
        },
        {
            "id": "2",
            "merchant_key": "tienda desconocida",
            "classification": "gasto",
            "category": "Otros",
            "account_name": "Ahorros *4821",
            "destination_account": None,
            "confidence": 0.62,
            "requires_review": True,
        },
        {
            "id": "3",
            "merchant_key": "alerta phishing",
            "classification": "sospechosa",
            "category": None,
            "account_name": None,
            "destination_account": None,
            "confidence": 0.0,
            "requires_review": True,
        },
    ]

    accepted, remaining = simulate_accept_all(pending)
    updates = [{"merchant_key": "exito laureles", "category": "Alimentación"}]
    if errs := validate_batch_result(pending, accepted, remaining, updates):
        print(f"FAIL self-test (lote válido): {errs}", file=sys.stderr)
        return 1

    # Caso que DEBE fallar: aceptar sospechosa en "aceptar todo"
    bad_accepted = [pending[0], pending[2]]
    bad_remaining = [pending[1]]
    if not validate_batch_result(pending, bad_accepted, bad_remaining, updates):
        print("FAIL self-test: debía rechazar aceptación de ítem 'sospechosa' en lote.", file=sys.stderr)
        return 1

    # Caso que DEBE fallar: olvidar actualizar learned_patterns
    if not validate_batch_result(pending, accepted, remaining, []):
        print("FAIL self-test: debía fallar si no se actualiza learned_patterns.", file=sys.stderr)
        return 1

    print("OK: moneo-feedback-loop self-test superado.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Verifica invariantes de moneo-feedback-loop.")
    parser.add_argument("batch_json", nargs="?", help="JSON con pending_before, accepted, remaining y learned_patterns_updates.")
    parser.add_argument("--self-test", action="store_true", help="Ejecuta pruebas positivas y negativas.")
    args = parser.parse_args()

    if args.self_test:
        return _run_self_test()

    if not args.batch_json:
        parser.print_help()
        return 2

    data = json.loads(Path(args.batch_json).read_text(encoding="utf-8"))
    errors = validate_batch_result(
        data["pending_before"],
        data["accepted"],
        data["remaining"],
        data.get("learned_patterns_updates", []),
    )
    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    print("OK: invariantes de feedback-loop verificados.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
