#!/usr/bin/env python3
"""Fail when DH comfort-threshold table misses coverage or citation fields.

This guard parses RE2020/RegulationTables.lean and validates
`dhComfortThresholdTable` used by calculateDHFromCanicule.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_TABLE_IDS = ["DH-COMFORT-LOW", "DH-COMFORT-MID", "DH-COMFORT-HIGH"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate DH threshold traceability coverage")
    parser.add_argument(
        "--source",
        default="RE2020/RegulationTables.lean",
        help="Path to RegulationTables Lean source",
    )
    return parser.parse_args()


def extract_rows(text: str) -> list[dict[str, str]]:
    m = re.search(
        r"def\s+dhComfortThresholdTable\s*:\s*List\s+ComfortThresholdBand\s*:=\s*\[(.*?)\]",
        text,
        re.S,
    )
    if not m:
        return []
    block = m.group(1)

    row_re = re.compile(
        r"\{\s*minRunningMean\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"maxRunningMean\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"comfortTemp\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )

    rows = []
    for min_rm, max_rm, comfort, section_id, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "minRunningMean": min_rm,
                "maxRunningMean": max_rm,
                "comfortTemp": comfort,
                "sectionId": section_id,
                "tableId": table_id,
                "articleRef": article_ref,
            }
        )
    return rows


def main() -> None:
    args = parse_args()
    src = Path(args.source)
    try:
        text = src.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"ERROR: source file not found: {src}")
        sys.exit(2)

    rows = extract_rows(text)
    errors: list[str] = []

    if not rows:
        errors.append("dhComfortThresholdTable is missing or could not be parsed")

    ids = set()
    bands: list[tuple[float, float]] = []
    for row in rows:
        table_id = row["tableId"]
        if table_id in ids:
            errors.append(f"duplicate tableId '{table_id}'")
        ids.add(table_id)

        if not row["sectionId"].strip() or not row["articleRef"].strip():
            errors.append(f"tableId '{table_id}' missing citation fields")

        min_rm = float(row["minRunningMean"])
        max_rm = float(row["maxRunningMean"])
        if min_rm >= max_rm:
            errors.append(f"tableId '{table_id}' has invalid band [{min_rm}, {max_rm})")
        bands.append((min_rm, max_rm))

    for required in REQUIRED_TABLE_IDS:
        if required not in ids:
            errors.append(f"missing required tableId '{required}'")

    if bands:
        bands_sorted = sorted(bands, key=lambda b: b[0])
        if bands_sorted[0][0] > 0.0:
            errors.append("first DH band must start at 0.0")
        prev_max = bands_sorted[0][1]
        for band in bands_sorted[1:]:
            if abs(band[0] - prev_max) > 1e-9:
                errors.append(f"gap/overlap between DH bands ending {prev_max} and starting {band[0]}")
            prev_max = band[1]

    print("DH traceability guard")
    print(f"- source: {src}")
    print("- required table IDs: " + ", ".join(REQUIRED_TABLE_IDS))

    if errors:
        print(f"\nFAIL: {len(errors)} blocking issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: DH comfort-threshold table has required coverage and citation fields")


if __name__ == "__main__":
    main()
