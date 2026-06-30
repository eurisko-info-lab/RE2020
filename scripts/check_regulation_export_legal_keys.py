#!/usr/bin/env python3
"""Validate machine-readable legal-key completeness in regulation export."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_TABLES = [
    "indicatorMethodCitations",
    "generatorConventionTable",
    "partLoadCurveConventionTable",
    "solarConventionTable",
    "perezSimplifiedBinTable",
]

REQUIRED_CITATION_FIELDS = ["sourceDoc", "sectionId", "tableId", "articleRef", "equationId", "version", "effectiveDate"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate legal-key completeness in regulation export")
    parser.add_argument(
        "--export",
        default="RE2020/data/regulation_tables_export.json",
        help="Path to exported regulation tables JSON",
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


def validate_citation(table_name: str, row_label: str, citation: Any) -> list[str]:
    if not isinstance(citation, dict):
        return [f"{table_name}: {row_label} missing citation object"]
    errors: list[str] = []
    for field in REQUIRED_CITATION_FIELDS:
        value = citation.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{table_name}: {row_label} missing citation field '{field}'")
    return errors


def main() -> None:
    args = parse_args()
    export_path = Path(args.export)
    data = load_export(export_path)

    tables = data.get("tables")
    if not isinstance(tables, dict):
        print("ERROR: export has no top-level 'tables' object")
        sys.exit(2)

    errors: list[str] = []
    for table_name in REQUIRED_TABLES:
        rows = tables.get(table_name)
        if not isinstance(rows, list):
            errors.append(f"{table_name}: expected list, got {type(rows).__name__}")
            continue
        for idx, row in enumerate(rows):
            if not isinstance(row, dict):
                errors.append(f"{table_name}: row #{idx} is not an object")
                continue
            row_label = row.get("tableId") or row.get("symbol") or row.get("key") or row.get("genType") or f"row #{idx}"
            errors.extend(validate_citation(table_name, str(row_label), row.get("citation")))

    print("Regulation export legal-key guard")
    print(f"- export: {export_path}")
    print("- required tables: " + ", ".join(REQUIRED_TABLES))

    if errors:
        print(f"\nFAIL: {len(errors)} issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: machine-readable regulation export carries required legal keys")


if __name__ == "__main__":
    main()
