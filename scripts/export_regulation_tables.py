#!/usr/bin/env python3
"""Export RE2020 regulation coefficient tables from Lean source to JSON.

This script parses RE2020/RegulationTables.lean and emits a machine-readable
snapshot for legal review and coefficient diffing.
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


def _extract_version(text: str) -> str:
    m = re.search(r'def\s+modulationTableVersion\s*:\s*String\s*:=\s*"([^"]+)"', text)
    if not m:
        raise ValueError("Could not find modulationTableVersion")
    return m.group(1)


def _extract_zone_entries(text: str) -> list[dict[str, object]]:
    pattern = re.compile(
        r"\{\s*zone\s*:=\s*\.(\w+),\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for zone, value, section, table_id, article_ref in pattern.findall(text):
        rows.append(
            {
                "zone": zone,
                "value": float(value),
                "citation": {
                    "sectionId": section,
                    "tableId": table_id,
                    "articleRef": article_ref,
                },
            }
        )
    return rows


def _extract_category_entries(text: str, table_name: str) -> list[dict[str, object]]:
    table_re = re.compile(rf"def\s+{re.escape(table_name)}\s*:\s*List\s+CategoryCoefficient\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*category\s*:=\s*\.(\w+),\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for category, value, section, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "category": category,
                "value": float(value),
                "citation": {
                    "sectionId": section,
                    "tableId": table_id,
                    "articleRef": article_ref,
                },
            }
        )
    return rows


def _extract_area_entries(text: str, table_name: str) -> list[dict[str, object]]:
    table_re = re.compile(rf"def\s+{re.escape(table_name)}\s*:\s*List\s+AreaBandCoefficient\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*minArea\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"maxArea\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for min_area, max_area, value, section, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "minArea": float(min_area),
                "maxArea": float(max_area),
                "value": float(value),
                "citation": {
                    "sectionId": section,
                    "tableId": table_id,
                    "articleRef": article_ref,
                },
            }
        )
    return rows


def _extract_usage_entries(text: str, table_name: str) -> list[dict[str, object]]:
    table_re = re.compile(rf"def\s+{re.escape(table_name)}\s*:\s*List\s+UsageFactorCoefficient\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*usage\s*:=\s*\"([^\"]+)\",\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for usage, value, section, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "usage": usage,
                "value": float(value),
                "citation": {
                    "sectionId": section,
                    "tableId": table_id,
                    "articleRef": article_ref,
                },
            }
        )
    return rows


def build_export(lean_text: str, source_path: str, include_generated_at: bool) -> dict[str, object]:
    metadata: dict[str, object] = {
        "source": source_path,
        "tableVersion": _extract_version(lean_text),
        "generator": "scripts/export_regulation_tables.py",
    }
    if include_generated_at:
        metadata["generatedAtUtc"] = datetime.now(timezone.utc).isoformat()

    return {
        "metadata": metadata,
        "tables": {
            "geoCoefficientTable": _extract_zone_entries(lean_text),
            "comblesCoefficientTable": _extract_category_entries(lean_text, "comblesCoefficientTable"),
            "bruitCoefficientTable": _extract_category_entries(lean_text, "bruitCoefficientTable"),
            "catCoefficientTable": _extract_category_entries(lean_text, "catCoefficientTable"),
            "surfMoyCoefficientTable": _extract_area_entries(lean_text, "surfMoyCoefficientTable"),
            "surfTotCoefficientTable": _extract_area_entries(lean_text, "surfTotCoefficientTable"),
            "primaryEnergyFactorTable": _extract_usage_entries(lean_text, "primaryEnergyFactorTable"),
            "nonRenewableEnergyFactorTable": _extract_usage_entries(lean_text, "nonRenewableEnergyFactorTable"),
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Export RE2020 regulation tables to JSON")
    parser.add_argument(
        "--input",
        default="RE2020/RegulationTables.lean",
        help="Path to RegulationTables Lean source",
    )
    parser.add_argument(
        "--output",
        default="RE2020/data/regulation_tables_export.json",
        help="Path to write exported JSON",
    )
    parser.add_argument(
        "--include-generated-at",
        action="store_true",
        help="Include generatedAtUtc timestamp in metadata (disabled by default for deterministic output)",
    )
    args = parser.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output)

    lean_text = in_path.read_text(encoding="utf-8")
    payload = build_export(lean_text, str(in_path), args.include_generated_at)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    total_rows = sum(len(v) for v in payload["tables"].values())
    print(f"Exported {total_rows} coefficient rows to {out_path}")


if __name__ == "__main__":
    main()
