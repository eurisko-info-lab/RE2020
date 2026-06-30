#!/usr/bin/env python3
"""Fail when modulation tables miss traceability coverage or citation fields.

This guard validates zone/category/area modulation tables in
RE2020/data/regulation_tables_export.json.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_CITATION_FIELDS = ["sectionId", "tableId", "articleRef"]
REQUIRED_ZONES = ["H1a", "H1b", "H1c", "H2a", "H2b", "H2c", "H2d", "H3"]
REQUIRED_CATEGORIES = [
    "MaisonIndividuelle",
    "LogementCollectif",
    "Bureau",
    "EnseignementPrimaireSecondaire",
    "Autre",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate modulation coefficient traceability coverage"
    )
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


def validate_citation(table_name: str, row_name: str, citation: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(citation, dict):
        return [f"{table_name}: {row_name} missing citation object"]
    for field in REQUIRED_CITATION_FIELDS:
        val = citation.get(field)
        if not isinstance(val, str) or not val.strip():
            errors.append(f"{table_name}: {row_name} missing citation field '{field}'")
    return errors


def validate_zone_table(table_rows: Any, table_name: str) -> list[str]:
    errors: list[str] = []
    if not isinstance(table_rows, list):
        return [f"{table_name}: expected list, got {type(table_rows).__name__}"]

    seen: dict[str, dict[str, Any]] = {}
    for idx, row in enumerate(table_rows):
        if not isinstance(row, dict):
            errors.append(f"{table_name}: row #{idx} is not an object")
            continue
        zone = row.get("zone")
        if not isinstance(zone, str) or not zone.strip():
            errors.append(f"{table_name}: row #{idx} missing non-empty 'zone'")
            continue
        if zone in seen:
            errors.append(f"{table_name}: duplicate zone '{zone}'")
            continue
        seen[zone] = row
        errors.extend(validate_citation(table_name, f"zone '{zone}'", row.get("citation")))

    for zone in REQUIRED_ZONES:
        if zone not in seen:
            errors.append(f"{table_name}: missing zone '{zone}'")

    return errors


def validate_category_table(table_rows: Any, table_name: str) -> list[str]:
    errors: list[str] = []
    if not isinstance(table_rows, list):
        return [f"{table_name}: expected list, got {type(table_rows).__name__}"]

    seen: dict[str, dict[str, Any]] = {}
    for idx, row in enumerate(table_rows):
        if not isinstance(row, dict):
            errors.append(f"{table_name}: row #{idx} is not an object")
            continue
        category = row.get("category")
        if not isinstance(category, str) or not category.strip():
            errors.append(f"{table_name}: row #{idx} missing non-empty 'category'")
            continue
        if category in seen:
            errors.append(f"{table_name}: duplicate category '{category}'")
            continue
        seen[category] = row
        errors.extend(
            validate_citation(table_name, f"category '{category}'", row.get("citation"))
        )

    for category in REQUIRED_CATEGORIES:
        if category not in seen:
            errors.append(f"{table_name}: missing category '{category}'")

    return errors


def validate_area_table(table_rows: Any, table_name: str) -> list[str]:
    errors: list[str] = []
    if not isinstance(table_rows, list):
        return [f"{table_name}: expected list, got {type(table_rows).__name__}"]

    bands: list[tuple[float, float]] = []
    for idx, row in enumerate(table_rows):
        if not isinstance(row, dict):
            errors.append(f"{table_name}: row #{idx} is not an object")
            continue
        min_area = row.get("minArea")
        max_area = row.get("maxArea")
        if not isinstance(min_area, (int, float)) or not isinstance(max_area, (int, float)):
            errors.append(f"{table_name}: row #{idx} has non-numeric minArea/maxArea")
            continue
        if float(min_area) >= float(max_area):
            errors.append(f"{table_name}: row #{idx} has invalid range [{min_area}, {max_area})")
            continue
        bands.append((float(min_area), float(max_area)))
        errors.extend(
            validate_citation(
                table_name,
                f"band [{float(min_area)}, {float(max_area)})",
                row.get("citation"),
            )
        )

    if bands:
        bands_sorted = sorted(bands, key=lambda b: b[0])
        if bands_sorted[0][0] > 0.0:
            errors.append(f"{table_name}: first band starts at {bands_sorted[0][0]}, expected 0.0")

        prev_max = bands_sorted[0][1]
        for current in bands_sorted[1:]:
            if abs(current[0] - prev_max) > 1e-9:
                errors.append(
                    f"{table_name}: gap/overlap between bands ending {prev_max} and starting {current[0]}"
                )
            prev_max = current[1]

    return errors


def main() -> None:
    args = parse_args()
    export_path = Path(args.export)
    data = load_export(export_path)

    tables = data.get("tables")
    if not isinstance(tables, dict):
        print("ERROR: export has no top-level 'tables' object")
        sys.exit(2)

    all_errors: list[str] = []
    all_errors.extend(validate_zone_table(tables.get("geoCoefficientTable"), "geoCoefficientTable"))
    all_errors.extend(
        validate_category_table(tables.get("comblesCoefficientTable"), "comblesCoefficientTable")
    )
    all_errors.extend(
        validate_category_table(tables.get("bruitCoefficientTable"), "bruitCoefficientTable")
    )
    all_errors.extend(
        validate_category_table(tables.get("catCoefficientTable"), "catCoefficientTable")
    )
    all_errors.extend(validate_area_table(tables.get("surfMoyCoefficientTable"), "surfMoyCoefficientTable"))
    all_errors.extend(validate_area_table(tables.get("surfTotCoefficientTable"), "surfTotCoefficientTable"))

    print("Modulation traceability guard")
    print(f"- export: {export_path}")
    print("- required zones: " + ", ".join(REQUIRED_ZONES))
    print("- required categories: " + ", ".join(REQUIRED_CATEGORIES))

    if all_errors:
        print(f"\nFAIL: {len(all_errors)} blocking issue(s) found")
        for err in all_errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: modulation tables have full coverage and citation fields")


if __name__ == "__main__":
    main()
