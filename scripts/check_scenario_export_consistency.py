#!/usr/bin/env python3
"""Fail when scenario export JSON drifts from Scenarios.lean source."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from scenario_traceability_common import extract_scenario_traceability


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate scenario export consistency")
    parser.add_argument("--source", default="RE2020/Scenarios.lean", help="Path to Scenarios.lean")
    parser.add_argument(
        "--export",
        default="RE2020/data/scenario_profiles_export.json",
        help="Path to scenario export JSON",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source_path = Path(args.source)
    export_path = Path(args.export)

    if not source_path.exists():
        print(f"ERROR: source file not found: {source_path}")
        sys.exit(2)

    try:
        exported = json.loads(export_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"ERROR: export file not found: {export_path}")
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {export_path}: {exc}")
        sys.exit(2)

    expected = extract_scenario_traceability(source_path)
    actual = exported.get("scenarioTraceability")

    print("Scenario export consistency guard")
    print(f"- source: {source_path}")
    print(f"- export: {export_path}")

    if actual != expected:
        print("\nFAIL: export content does not match current source")
        print("Re-run: python3 scripts/export_scenario_profiles.py")
        sys.exit(1)

    print("\nPASS: export matches source traceability data")


if __name__ == "__main__":
    main()
