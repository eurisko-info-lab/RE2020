#!/usr/bin/env python3
"""Fail when Bbio weighting table is missing coverage or citation fields.

This guard parses RE2020/RegulationTables.lean directly and checks that
bbioWeightTable provides the required terms with citation metadata.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_TERMS = ["heating_need", "cooling_need", "lighting_need"]
REQUIRED_CITATION_FIELDS = ["sectionId", "tableId", "articleRef"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Bbio weight traceability coverage")
    parser.add_argument(
        "--source",
        default="RE2020/RegulationTables.lean",
        help="Path to RegulationTables Lean source",
    )
    return parser.parse_args()


def extract_bbio_rows(text: str) -> list[dict[str, str]]:
    table_match = re.search(
        r"def\s+bbioWeightTable\s*:\s*List\s+UsageFactorCoefficient\s*:=\s*\[(.*?)\]",
        text,
        re.S,
    )
    if not table_match:
        return []

    block = table_match.group(1)
    row_re = re.compile(
        r"\{\s*usage\s*:=\s*\"([^\"]+)\",\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for usage, value, section_id, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "usage": usage,
                "value": value,
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

    rows = extract_bbio_rows(text)

    errors: list[str] = []
    if not rows:
        errors.append("bbioWeightTable is missing or could not be parsed")

    by_term: dict[str, dict[str, str]] = {}
    for row in rows:
        term = row["usage"]
        if term in by_term:
            errors.append(f"duplicate Bbio term '{term}'")
            continue
        by_term[term] = row

    for term in REQUIRED_TERMS:
        row = by_term.get(term)
        if row is None:
            errors.append(f"missing Bbio term '{term}'")
            continue

        for field in REQUIRED_CITATION_FIELDS:
            value = row.get(field, "")
            if not value.strip():
                errors.append(f"term '{term}' missing citation field '{field}'")

    print("Bbio traceability guard")
    print(f"- source: {src}")
    print("- required terms: " + ", ".join(REQUIRED_TERMS))

    if errors:
        print(f"\nFAIL: {len(errors)} blocking issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: bbioWeightTable has full coverage and citation fields")


if __name__ == "__main__":
    main()
