#!/usr/bin/env python3
"""Fail when scenario/end-use profile traceability coverage is incomplete.

This guard validates RE2020/Scenarios.lean source for:
- required category coverage in getScenario/getScenarioCitation/getEndUseProfile/getEndUseProfileCitation
- basic end-use profile value sanity
- citation presence for each hourly-scenario and end-use profile family
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_CATEGORIES = [
    "BuildingCategory.MaisonIndividuelle",
    "BuildingCategory.LogementCollectif",
    "BuildingCategory.Bureau",
    "BuildingCategory.EnseignementPrimaireSecondaire",
]

REQUIRED_PROFILE_DEFS = [
    "residentialEndUseProfile",
    "officeEndUseProfile",
    "teachingEndUseProfile",
]

REQUIRED_CITATION_DEFS = [
    "residentialEndUseCitation",
    "officeEndUseCitation",
    "teachingEndUseCitation",
]

REQUIRED_SCENARIO_CITATION_DEFS = [
    "residentialScenarioCitation",
    "officeScenarioCitation",
    "teachingScenarioCitation",
]

REQUIRED_CITATION_FIELDS = ["sourceDoc", "sectionId", "tableId", "articleRef", "equationId", "version", "effectiveDate"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate scenario profile traceability in Scenarios.lean"
    )
    parser.add_argument(
        "--input",
        default="RE2020/Scenarios.lean",
        help="Path to Scenarios Lean source",
    )
    return parser.parse_args()


def find_def_block(text: str, def_name: str) -> str | None:
    m = re.search(rf"def\s+{re.escape(def_name)}\b.*?:=", text)
    if not m:
        return None
    start = m.start()
    rest = text[start:]
    next_def = re.search(r"\ndef\s+", rest[1:])
    if not next_def:
        return rest
    return rest[: next_def.start() + 1]


def parse_profile_field(block: str, field: str) -> float | None:
    m = re.search(rf"{re.escape(field)}\s*:=\s*([0-9]+(?:\.[0-9]+)?)", block)
    if not m:
        return None
    return float(m.group(1))


def validate_profile_block(name: str, block: str | None) -> list[str]:
    if block is None:
        return [f"missing profile definition: {name}"]

    errors: list[str] = []
    dhw_daily = parse_profile_field(block, "dhwDailyNeedPerM2")
    dhw_losses = parse_profile_field(block, "dhwStorageLossesPerM2")
    aux_hours = parse_profile_field(block, "auxiliaryOperatingHours")

    if dhw_daily is None:
        errors.append(f"{name}: missing dhwDailyNeedPerM2")
    elif dhw_daily <= 0:
        errors.append(f"{name}: dhwDailyNeedPerM2 must be > 0")

    if dhw_losses is None:
        errors.append(f"{name}: missing dhwStorageLossesPerM2")
    elif dhw_losses < 0:
        errors.append(f"{name}: dhwStorageLossesPerM2 must be >= 0")

    if aux_hours is None:
        errors.append(f"{name}: missing auxiliaryOperatingHours")
    elif aux_hours <= 0:
        errors.append(f"{name}: auxiliaryOperatingHours must be > 0")

    return errors


def validate_citation_block(name: str, block: str | None) -> list[str]:
    if block is None:
        return [f"missing citation definition: {name}"]

    errors: list[str] = []
    for field in REQUIRED_CITATION_FIELDS:
        m = re.search(rf"{re.escape(field)}\s*:=\s*\"([^\"]+)\"", block)
        if not m or not m.group(1).strip():
            errors.append(f"{name}: missing citation field '{field}'")
    return errors


def main() -> None:
    args = parse_args()
    path = Path(args.input)

    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"ERROR: file not found: {path}")
        sys.exit(2)

    all_errors: list[str] = []

    for fn in ["getScenario", "getScenarioCitation", "getEndUseProfile", "getEndUseProfileCitation"]:
        block = find_def_block(text, fn)
        if block is None:
            all_errors.append(f"missing function: {fn}")
            continue
        for category in REQUIRED_CATEGORIES:
            if category not in block:
                all_errors.append(f"{fn}: missing category mapping {category}")

    for name in REQUIRED_SCENARIO_CITATION_DEFS:
        all_errors.extend(validate_citation_block(name, find_def_block(text, name)))

    for name in REQUIRED_PROFILE_DEFS:
        all_errors.extend(validate_profile_block(name, find_def_block(text, name)))

    for name in REQUIRED_CITATION_DEFS:
        all_errors.extend(validate_citation_block(name, find_def_block(text, name)))

    print("Scenario profile traceability guard")
    print(f"- source: {path}")
    print(f"- required categories: {', '.join(REQUIRED_CATEGORIES)}")

    if all_errors:
        print(f"\nFAIL: {len(all_errors)} issue(s) found")
        for err in all_errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: scenario/profile coverage and citations are present")


if __name__ == "__main__":
    main()
