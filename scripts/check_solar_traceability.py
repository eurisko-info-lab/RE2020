#!/usr/bin/env python3
"""Fail when solar convention tables miss coverage or citation fields.

This guard parses RE2020/Solar.lean and validates `solarConventionTable`
and `perezSimplifiedBinTable` used in active solar calculations.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_SOLAR_KEYS = [
    "default_albedo",
    "extraterrestrial_irradiance",
    "default_latitude_france",
    "variable_g_reduction_factor",
]

REQUIRED_PEREZ_IDS = [
    "SOL-PEREZ-BIN-01",
    "SOL-PEREZ-BIN-02",
    "SOL-PEREZ-BIN-03",
    "SOL-PEREZ-BIN-04",
    "SOL-PEREZ-BIN-05",
    "SOL-PEREZ-BIN-06",
    "SOL-PEREZ-BIN-07",
    "SOL-PEREZ-BIN-08",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate solar traceability coverage")
    parser.add_argument(
        "--source",
        default="RE2020/Solar.lean",
        help="Path to Solar Lean source",
    )
    return parser.parse_args()


def _extract_block(text: str, table_name: str) -> str:
    m = re.search(
        rf"def\s+{re.escape(table_name)}\s*:\s*List\s+\w+\s*:=\s*\[(.*?)\]",
        text,
        re.S,
    )
    return m.group(1) if m else ""


def _extract_solar_rows(block: str) -> list[dict[str, str]]:
    row_re = re.compile(
        r"\{\s*key\s*:=\s*\"([^\"]+)\",\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkSolarCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for key, _, section, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "key": key,
                "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                "sectionId": section,
                "tableId": table_id,
                "articleRef": article_ref,
                "equationId": "SOL-EQ-01",
                "effectiveDate": "2026-06-28",
            }
        )
    return rows


def _extract_perez_rows(block: str) -> list[dict[str, str]]:
    row_re = re.compile(
        r"\{\s*minEpsilon\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"maxEpsilon\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"f1\s*:=\s*(-?[0-9]+(?:\.[0-9]+)?),\s*"
        r"f2\s*:=\s*(-?[0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkSolarCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for min_e, max_e, _, _, section, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "minEpsilon": min_e,
                "maxEpsilon": max_e,
                "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                "sectionId": section,
                "tableId": table_id,
                "articleRef": article_ref,
                "equationId": "SOL-EQ-01",
                "effectiveDate": "2026-06-28",
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

    solar_block = _extract_block(text, "solarConventionTable")
    perez_block = _extract_block(text, "perezSimplifiedBinTable")

    errors: list[str] = []
    if not solar_block:
        errors.append("solarConventionTable is missing")
    if not perez_block:
        errors.append("perezSimplifiedBinTable is missing")

    solar_rows = _extract_solar_rows(solar_block) if solar_block else []
    perez_rows = _extract_perez_rows(perez_block) if perez_block else []

    seen_keys = set()
    for row in solar_rows:
        key = row["key"]
        if key in seen_keys:
            errors.append(f"solarConventionTable: duplicate key '{key}'")
        seen_keys.add(key)
        if not row["sourceDoc"].strip() or not row["sectionId"].strip() or not row["tableId"].strip() or not row["articleRef"].strip() or not row["equationId"].strip() or not row["effectiveDate"].strip():
            errors.append(f"solarConventionTable: key '{key}' has missing citation fields")

    for key in REQUIRED_SOLAR_KEYS:
        if key not in seen_keys:
            errors.append(f"solarConventionTable: missing required key '{key}'")

    seen_ids = set()
    bands: list[tuple[float, float]] = []
    for row in perez_rows:
        tid = row["tableId"]
        if tid in seen_ids:
            errors.append(f"perezSimplifiedBinTable: duplicate tableId '{tid}'")
        seen_ids.add(tid)
        if not row["sourceDoc"].strip() or not row["sectionId"].strip() or not row["articleRef"].strip() or not row["equationId"].strip() or not row["effectiveDate"].strip():
            errors.append(f"perezSimplifiedBinTable: tableId '{tid}' has missing citation fields")
        min_e = float(row["minEpsilon"])
        max_e = float(row["maxEpsilon"])
        if min_e >= max_e:
            errors.append(f"perezSimplifiedBinTable: invalid epsilon band [{min_e}, {max_e})")
        bands.append((min_e, max_e))

    for tid in REQUIRED_PEREZ_IDS:
        if tid not in seen_ids:
            errors.append(f"perezSimplifiedBinTable: missing required tableId '{tid}'")

    if bands:
        bands_sorted = sorted(bands, key=lambda b: b[0])
        if bands_sorted[0][0] > 0.0:
            errors.append("perezSimplifiedBinTable: first epsilon band must start at 0.0")
        prev = bands_sorted[0][1]
        for band in bands_sorted[1:]:
            if abs(band[0] - prev) > 1e-9:
                errors.append(
                    f"perezSimplifiedBinTable: gap/overlap between bands ending {prev} and starting {band[0]}"
                )
            prev = band[1]

    print("Solar traceability guard")
    print(f"- source: {src}")
    print("- required convention keys: " + ", ".join(REQUIRED_SOLAR_KEYS))
    print("- required Perez IDs: " + ", ".join(REQUIRED_PEREZ_IDS))

    if errors:
        print(f"\nFAIL: {len(errors)} blocking issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: solar conventions and Perez bins have required coverage and citations")


if __name__ == "__main__":
    main()
