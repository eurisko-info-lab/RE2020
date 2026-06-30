#!/usr/bin/env python3
"""Fail when required pipeline usages are missing factor traceability coverage.

This guard validates both primary and non-renewable factor tables in
RE2020/data/regulation_tables_export.json.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


DEFAULT_REQUIRED_USAGES = ["heating", "dhw", "cooling", "lighting", "auxiliaries"]
REQUIRED_CITATION_FIELDS = ["sectionId", "tableId", "articleRef"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate usage-factor traceability coverage for Cep/Cep_nr pipeline usages"
    )
    parser.add_argument(
        "--export",
        default="RE2020/data/regulation_tables_export.json",
        help="Path to exported regulation tables JSON",
    )
    parser.add_argument(
        "--required-usages",
        default=",".join(DEFAULT_REQUIRED_USAGES),
        help="Comma-separated required usages",
    )
    return parser.parse_args()


def load_export(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"ERROR: export file not found: {path}")
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {path}: {exc}")
        sys.exit(2)


def parse_required_usages(raw: str) -> list[str]:
    usages = [u.strip() for u in raw.split(",") if u.strip()]
    if not usages:
        print("ERROR: required usage list is empty")
        sys.exit(2)
    return usages


def validate_table(
    table_name: str,
    table_rows: Any,
    required_usages: list[str],
) -> list[str]:
    errors: list[str] = []

    if not isinstance(table_rows, list):
        return [f"{table_name}: expected list, got {type(table_rows).__name__}"]

    rows_by_usage: dict[str, list[dict[str, Any]]] = {}
    for idx, row in enumerate(table_rows):
        if not isinstance(row, dict):
            errors.append(f"{table_name}: row #{idx} is not an object")
            continue

        usage = row.get("usage")
        if not isinstance(usage, str) or not usage.strip():
            errors.append(f"{table_name}: row #{idx} missing non-empty 'usage'")
            continue

        rows_by_usage.setdefault(usage, []).append(row)

    for usage in required_usages:
        matches = rows_by_usage.get(usage, [])
        if not matches:
            errors.append(f"{table_name}: missing usage '{usage}'")
            continue
        if len(matches) > 1:
            errors.append(f"{table_name}: duplicate usage '{usage}' ({len(matches)} rows)")
            continue

        row = matches[0]
        value = row.get("value")
        if not isinstance(value, (int, float)):
            errors.append(f"{table_name}: usage '{usage}' has non-numeric value")

        citation = row.get("citation")
        if not isinstance(citation, dict):
            errors.append(f"{table_name}: usage '{usage}' missing citation object")
            continue

        for field in REQUIRED_CITATION_FIELDS:
            field_val = citation.get(field)
            if not isinstance(field_val, str) or not field_val.strip():
                errors.append(
                    f"{table_name}: usage '{usage}' missing citation field '{field}'"
                )

    return errors


def main() -> None:
    args = parse_args()
    required_usages = parse_required_usages(args.required_usages)
    export_path = Path(args.export)
    data = load_export(export_path)

    tables = data.get("tables")
    if not isinstance(tables, dict):
        print("ERROR: export has no top-level 'tables' object")
        sys.exit(2)

    primary = tables.get("primaryEnergyFactorTable")
    non_renewable = tables.get("nonRenewableEnergyFactorTable")

    all_errors: list[str] = []
    all_errors.extend(validate_table("primaryEnergyFactorTable", primary, required_usages))
    all_errors.extend(
        validate_table("nonRenewableEnergyFactorTable", non_renewable, required_usages)
    )

    print("Usage factor traceability guard")
    print(f"- export: {export_path}")
    print(f"- required usages: {', '.join(required_usages)}")

    if all_errors:
        print(f"\nFAIL: {len(all_errors)} blocking issue(s) found")
        for err in all_errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: all required usages have factor + citation coverage")


if __name__ == "__main__":
    main()
