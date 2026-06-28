#!/usr/bin/env python3
"""Fail when benchmark cases miss official reference mapping metadata.

This guard parses RE2020/RE2020.lean and validates that
standardValidationBenchmarkCases include reference metadata fields.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate benchmark reference traceability")
    parser.add_argument(
        "--source",
        default="RE2020/RE2020.lean",
        help="Path to RE2020 Lean source",
    )
    return parser.parse_args()


def extract_case_rows(text: str) -> list[dict[str, str]]:
    row_re = re.compile(
        r"\{\s*caseId\s*:=\s*\"([^\"]+)\",\s*"
        r"reference\s*:=\s*\{\s*"
        r"sourceDoc\s*:=\s*\"([^\"]+)\",\s*"
        r"officialCaseId\s*:=\s*\"([^\"]+)\",\s*"
        r"toleranceProfile\s*:=\s*\"([^\"]+)\",\s*"
        r"citationId\s*:=\s*\"([^\"]+)\"\s*\}",
        re.S,
    )

    rows = []
    for case_id, source_doc, official_case_id, tolerance_profile, citation_id in row_re.findall(text):
        rows.append(
            {
                "caseId": case_id,
                "sourceDoc": source_doc,
                "officialCaseId": official_case_id,
                "toleranceProfile": tolerance_profile,
                "citationId": citation_id,
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

    rows = extract_case_rows(text)
    errors: list[str] = []

    if not rows:
        errors.append("standardValidationBenchmarkCases missing or no reference metadata parsed")

    by_case_id = set()
    by_official_case_id = set()

    for row in rows:
        case_id = row["caseId"]
        official_case_id = row["officialCaseId"]

        if case_id in by_case_id:
            errors.append(f"duplicate caseId '{case_id}'")
        by_case_id.add(case_id)

        if official_case_id in by_official_case_id:
            errors.append(f"duplicate officialCaseId '{official_case_id}'")
        by_official_case_id.add(official_case_id)

        for field in ["sourceDoc", "officialCaseId", "toleranceProfile", "citationId"]:
            if not row[field].strip():
                errors.append(f"caseId '{case_id}' missing '{field}'")

    if len(rows) < 4:
        errors.append(f"expected at least 4 benchmark cases, found {len(rows)}")

    print("Validation reference traceability guard")
    print(f"- source: {src}")
    print(f"- benchmark cases parsed: {len(rows)}")

    if errors:
        print(f"\nFAIL: {len(errors)} blocking issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: benchmark cases have official reference mapping metadata")


if __name__ == "__main__":
    main()
