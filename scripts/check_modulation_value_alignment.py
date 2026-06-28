#!/usr/bin/env python3
"""Fail when modulation table values/IDs drift from the baseline alignment profile.

This guard compares modulation rows in RE2020/regulation_tables_export.json against
an expected baseline snapshot (values + table IDs) to enforce deterministic
alignment tracking before official legal-source reconciliation.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any


TOLERANCE = 1e-9

EXPECTED_GEO: dict[str, tuple[float, str]] = {
    "H1a": (0.15, "MBGEO-H1a"),
    "H1b": (0.13, "MBGEO-H1b"),
    "H1c": (0.11, "MBGEO-H1c"),
    "H2a": (0.08, "MBGEO-H2a"),
    "H2b": (0.06, "MBGEO-H2b"),
    "H2c": (0.04, "MBGEO-H2c"),
    "H2d": (0.05, "MBGEO-H2d"),
    "H3": (0.02, "MBGEO-H3"),
}

EXPECTED_COMBLES: dict[str, tuple[float, str]] = {
    "MaisonIndividuelle": (0.04, "MBCOMBLES-MI"),
    "LogementCollectif": (0.02, "MBCOMBLES-LC"),
    "Bureau": (0.01, "MBCOMBLES-BUR"),
    "EnseignementPrimaireSecondaire": (0.015, "MBCOMBLES-ENS"),
    "Autre": (0.01, "MBCOMBLES-AUT"),
}

EXPECTED_BRUIT: dict[str, tuple[float, str]] = {
    "MaisonIndividuelle": (0.0, "MBBRUIT-MI"),
    "LogementCollectif": (0.01, "MBBRUIT-LC"),
    "Bureau": (0.02, "MBBRUIT-BUR"),
    "EnseignementPrimaireSecondaire": (0.015, "MBBRUIT-ENS"),
    "Autre": (0.01, "MBBRUIT-AUT"),
}

EXPECTED_CAT: dict[str, tuple[float, str]] = {
    "MaisonIndividuelle": (0.0, "MCCAT-MI"),
    "LogementCollectif": (0.01, "MCCAT-LC"),
    "Bureau": (0.03, "MCCAT-BUR"),
    "EnseignementPrimaireSecondaire": (0.02, "MCCAT-ENS"),
    "Autre": (0.015, "MCCAT-AUT"),
}

EXPECTED_SURF_MOY: dict[str, tuple[float, str]] = {
    "0.0|60.0": (0.05, "MBSURFMOY-000-060"),
    "60.0|120.0": (0.03, "MBSURFMOY-060-120"),
    "120.0|300.0": (0.015, "MBSURFMOY-120-300"),
    "300.0|1000000000.0": (0.0, "MBSURFMOY-300-INF"),
}

EXPECTED_SURF_TOT: dict[str, tuple[float, str]] = {
    "0.0|100.0": (0.03, "MBSURFTOT-000-100"),
    "100.0|500.0": (0.015, "MBSURFTOT-100-500"),
    "500.0|2000.0": (0.005, "MBSURFTOT-500-2000"),
    "2000.0|1000000000.0": (0.0, "MBSURFTOT-2000-INF"),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate modulation value alignment")
    parser.add_argument(
        "--export",
        default="RE2020/regulation_tables_export.json",
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


def _is_close(a: float, b: float) -> bool:
    return math.isclose(a, b, rel_tol=0.0, abs_tol=TOLERANCE)


def _validate_keyed_rows(
    table_name: str,
    rows: Any,
    key_field: str,
    expected: dict[str, tuple[float, str]],
) -> list[str]:
    errors: list[str] = []
    if not isinstance(rows, list):
        return [f"{table_name}: expected list, got {type(rows).__name__}"]

    actual: dict[str, tuple[float, str]] = {}
    for idx, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(f"{table_name}: row #{idx} is not an object")
            continue

        key = row.get(key_field)
        value = row.get("value")
        citation = row.get("citation")

        if not isinstance(key, str):
            errors.append(f"{table_name}: row #{idx} missing string '{key_field}'")
            continue
        if not isinstance(value, (int, float)):
            errors.append(f"{table_name}: row #{idx} has non-numeric value")
            continue
        if not isinstance(citation, dict):
            errors.append(f"{table_name}: row #{idx} missing citation")
            continue

        table_id = citation.get("tableId")
        if not isinstance(table_id, str):
            errors.append(f"{table_name}: row #{idx} missing citation.tableId")
            continue

        if key in actual:
            errors.append(f"{table_name}: duplicate key '{key}'")
            continue
        actual[key] = (float(value), table_id)

    for key, (expected_value, expected_id) in expected.items():
        if key not in actual:
            errors.append(f"{table_name}: missing key '{key}'")
            continue
        got_value, got_id = actual[key]
        if not _is_close(got_value, expected_value):
            errors.append(
                f"{table_name}: key '{key}' value drift (got {got_value}, expected {expected_value})"
            )
        if got_id != expected_id:
            errors.append(
                f"{table_name}: key '{key}' tableId drift (got '{got_id}', expected '{expected_id}')"
            )

    for key in actual:
        if key not in expected:
            errors.append(f"{table_name}: unexpected key '{key}'")

    return errors


def _validate_area_rows(
    table_name: str,
    rows: Any,
    expected: dict[str, tuple[float, str]],
) -> list[str]:
    errors: list[str] = []
    if not isinstance(rows, list):
        return [f"{table_name}: expected list, got {type(rows).__name__}"]

    actual: dict[str, tuple[float, str]] = {}
    for idx, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(f"{table_name}: row #{idx} is not an object")
            continue

        min_area = row.get("minArea")
        max_area = row.get("maxArea")
        value = row.get("value")
        citation = row.get("citation")

        if not isinstance(min_area, (int, float)) or not isinstance(max_area, (int, float)):
            errors.append(f"{table_name}: row #{idx} has invalid minArea/maxArea")
            continue
        if not isinstance(value, (int, float)):
            errors.append(f"{table_name}: row #{idx} has non-numeric value")
            continue
        if not isinstance(citation, dict):
            errors.append(f"{table_name}: row #{idx} missing citation")
            continue

        table_id = citation.get("tableId")
        if not isinstance(table_id, str):
            errors.append(f"{table_name}: row #{idx} missing citation.tableId")
            continue

        key = f"{float(min_area)}|{float(max_area)}"
        if key in actual:
            errors.append(f"{table_name}: duplicate band '{key}'")
            continue
        actual[key] = (float(value), table_id)

    for key, (expected_value, expected_id) in expected.items():
        if key not in actual:
            errors.append(f"{table_name}: missing band '{key}'")
            continue
        got_value, got_id = actual[key]
        if not _is_close(got_value, expected_value):
            errors.append(
                f"{table_name}: band '{key}' value drift (got {got_value}, expected {expected_value})"
            )
        if got_id != expected_id:
            errors.append(
                f"{table_name}: band '{key}' tableId drift (got '{got_id}', expected '{expected_id}')"
            )

    for key in actual:
        if key not in expected:
            errors.append(f"{table_name}: unexpected band '{key}'")

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
    errors.extend(_validate_keyed_rows("geoCoefficientTable", tables.get("geoCoefficientTable"), "zone", EXPECTED_GEO))
    errors.extend(_validate_keyed_rows("comblesCoefficientTable", tables.get("comblesCoefficientTable"), "category", EXPECTED_COMBLES))
    errors.extend(_validate_keyed_rows("bruitCoefficientTable", tables.get("bruitCoefficientTable"), "category", EXPECTED_BRUIT))
    errors.extend(_validate_keyed_rows("catCoefficientTable", tables.get("catCoefficientTable"), "category", EXPECTED_CAT))
    errors.extend(_validate_area_rows("surfMoyCoefficientTable", tables.get("surfMoyCoefficientTable"), EXPECTED_SURF_MOY))
    errors.extend(_validate_area_rows("surfTotCoefficientTable", tables.get("surfTotCoefficientTable"), EXPECTED_SURF_TOT))

    print("Modulation value-alignment guard")
    print(f"- export: {export_path}")
    print("- profile: baseline-v1")

    if errors:
        print(f"\nFAIL: {len(errors)} blocking issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: modulation values and table IDs match baseline-v1 profile")


if __name__ == "__main__":
    main()
