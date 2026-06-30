#!/usr/bin/env python3
"""Validate machine-readable legal-key completeness in scenario export."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_CITATION_FIELDS = ["sourceDoc", "sectionId", "tableId", "articleRef", "equationId", "version", "effectiveDate"]
REQUIRED_CITATION_KEYS = [
    "residentialEndUseCitation",
    "officeEndUseCitation",
    "teachingEndUseCitation",
    "residentialScenarioCitation",
    "officeScenarioCitation",
    "teachingScenarioCitation",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate legal-key completeness in scenario export")
    parser.add_argument(
        "--export",
        default="RE2020/data/scenario_profiles_export.json",
        help="Path to scenario profile export JSON",
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


def main() -> None:
    args = parse_args()
    export_path = Path(args.export)
    data = load_export(export_path)

    trace = data.get("scenarioTraceability")
    if not isinstance(trace, dict):
        print("ERROR: export has no top-level 'scenarioTraceability' object")
        sys.exit(2)

    citations = trace.get("citations")
    if not isinstance(citations, dict):
        print("ERROR: export has no 'scenarioTraceability.citations' object")
        sys.exit(2)

    errors: list[str] = []
    for key in REQUIRED_CITATION_KEYS:
        citation = citations.get(key)
        if not isinstance(citation, dict):
            errors.append(f"missing citation '{key}'")
            continue
        for field in REQUIRED_CITATION_FIELDS:
            value = citation.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{key}: missing citation field '{field}'")

    print("Scenario export legal-key guard")
    print(f"- export: {export_path}")
    print("- required citations: " + ", ".join(REQUIRED_CITATION_KEYS))

    if errors:
        print(f"\nFAIL: {len(errors)} issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: machine-readable scenario export carries required legal keys")


if __name__ == "__main__":
    main()
