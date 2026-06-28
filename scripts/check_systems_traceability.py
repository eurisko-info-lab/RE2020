#!/usr/bin/env python3
"""Fail when systems convention tables miss coverage or citation fields.

This guard parses RE2020/Systems.lean and validates generator conventions and
part-load curve conventions used by the active systems path.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_GENERATORS = [
    "GasBoilerCondensing",
    "OilBoiler",
    "WoodBoiler",
    "HeatPumpAirAir",
    "HeatPumpAirWater",
    "HeatPumpWaterWater",
    "DistrictHeating",
    "ElectricHeating",
]

REQUIRED_PARTLOAD_CURVE_GENERATORS = [
    "GasBoilerCondensing",
    "WoodBoiler",
    "HeatPumpAirAir",
    "HeatPumpAirWater",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate systems traceability coverage")
    parser.add_argument(
        "--source",
        default="RE2020/Systems.lean",
        help="Path to Systems Lean source",
    )
    return parser.parse_args()


def _extract_table_block(text: str, table_name: str) -> str:
    m = re.search(
        rf"def\s+{re.escape(table_name)}\s*:\s*List\s+\w+\s*:=\s*\[(.*?)\]",
        text,
        re.S,
    )
    return m.group(1) if m else ""


def _extract_generator_rows(block: str) -> list[dict[str, str]]:
    row_re = re.compile(
        r"\{\s*genType\s*:=\s*\.(\w+),\s*"
        r"nominalEfficiency\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"seasonalPerformance\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"auxiliaryPower\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"primaryEnergyFactor\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkSystemCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for gen_type, _, _, _, _, section_id, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "genType": gen_type,
                "sectionId": section_id,
                "tableId": table_id,
                "articleRef": article_ref,
            }
        )
    return rows


def _extract_partload_rows(block: str) -> list[dict[str, str]]:
    row_re = re.compile(
        r"\{\s*genType\s*:=\s*\.(\w+),\s*"
        r"a0\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"a1\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"a2\s*:=\s*(-?[0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkSystemCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for gen_type, _, _, _, section_id, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "genType": gen_type,
                "sectionId": section_id,
                "tableId": table_id,
                "articleRef": article_ref,
            }
        )
    return rows


def _validate_unique_and_coverage(rows: list[dict[str, str]], key: str, required: list[str], label: str) -> list[str]:
    errors: list[str] = []
    seen: dict[str, dict[str, str]] = {}
    for row in rows:
        value = row[key]
        if value in seen:
            errors.append(f"{label}: duplicate {key} '{value}'")
            continue
        seen[value] = row
        for field in ["sectionId", "tableId", "articleRef"]:
            if not row[field].strip():
                errors.append(f"{label}: {key} '{value}' missing citation field '{field}'")
    for value in required:
        if value not in seen:
            errors.append(f"{label}: missing required {key} '{value}'")
    return errors


def main() -> None:
    args = parse_args()
    src = Path(args.source)
    try:
        text = src.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"ERROR: source file not found: {src}")
        sys.exit(2)

    gen_block = _extract_table_block(text, "generatorConventionTable")
    curve_block = _extract_table_block(text, "partLoadCurveConventionTable")

    errors: list[str] = []
    if not gen_block:
        errors.append("generatorConventionTable is missing")
    if not curve_block:
        errors.append("partLoadCurveConventionTable is missing")

    gen_rows = _extract_generator_rows(gen_block) if gen_block else []
    curve_rows = _extract_partload_rows(curve_block) if curve_block else []

    errors.extend(
        _validate_unique_and_coverage(
            gen_rows,
            key="genType",
            required=REQUIRED_GENERATORS,
            label="generatorConventionTable",
        )
    )
    errors.extend(
        _validate_unique_and_coverage(
            curve_rows,
            key="genType",
            required=REQUIRED_PARTLOAD_CURVE_GENERATORS,
            label="partLoadCurveConventionTable",
        )
    )

    print("Systems traceability guard")
    print(f"- source: {src}")
    print("- required generators: " + ", ".join(REQUIRED_GENERATORS))
    print(
        "- required part-load curves: "
        + ", ".join(REQUIRED_PARTLOAD_CURVE_GENERATORS)
    )

    if errors:
        print(f"\nFAIL: {len(errors)} blocking issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: systems conventions have required coverage and citation fields")


if __name__ == "__main__":
    main()
