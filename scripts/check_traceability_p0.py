#!/usr/bin/env python3
"""Fail CI when any required-priority traceability item is still Missing.

Default behavior enforces that all P0 entries in
RE2020/regulation_traceability_matrix.json are not Missing.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate regulation traceability status by priority."
    )
    parser.add_argument(
        "--matrix",
        default="RE2020/regulation_traceability_matrix.json",
        help="Path to traceability JSON matrix.",
    )
    parser.add_argument(
        "--priorities",
        default="P0",
        help="Comma-separated priorities to enforce (e.g. P0 or P0,P1).",
    )
    parser.add_argument(
        "--failing-status",
        default="Missing",
        help="Status value considered failing (default: Missing).",
    )
    return parser.parse_args()


def load_entries(path: Path) -> list[dict[str, Any]]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"ERROR: matrix file not found: {path}")
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {path}: {exc}")
        sys.exit(2)

    entries = raw.get("entries")
    if not isinstance(entries, list):
        print(f"ERROR: JSON file {path} has no top-level 'entries' list")
        sys.exit(2)

    valid_entries: list[dict[str, Any]] = []
    for idx, item in enumerate(entries):
        if not isinstance(item, dict):
            print(f"ERROR: entry #{idx} is not an object")
            sys.exit(2)
        valid_entries.append(item)
    return valid_entries


def main() -> None:
    args = parse_args()
    matrix_path = Path(args.matrix)
    priorities = {p.strip() for p in args.priorities.split(",") if p.strip()}
    if not priorities:
        print("ERROR: at least one priority is required")
        sys.exit(2)

    entries = load_entries(matrix_path)

    scoped = [e for e in entries if str(e.get("priority", "")).strip() in priorities]
    failing = [
        e
        for e in scoped
        if str(e.get("status", "")).strip().lower() == args.failing_status.strip().lower()
    ]

    print("Traceability guard")
    print(f"- matrix: {matrix_path}")
    print(f"- enforced priorities: {', '.join(sorted(priorities))}")
    print(f"- failing status: {args.failing_status}")
    print(f"- scoped entries: {len(scoped)}")

    if not scoped:
        print("ERROR: no entries matched the requested priorities")
        sys.exit(2)

    if failing:
        print(f"\nFAIL: {len(failing)} blocking entries detected")
        for i, entry in enumerate(failing, start=1):
            domain = entry.get("domain", "<unknown>")
            code_anchor = entry.get("codeAnchor", "<unknown>")
            evidence = entry.get("evidence", "")
            priority = entry.get("priority", "")
            print(f"{i}. [{priority}] {domain}")
            print(f"   code: {code_anchor}")
            if evidence:
                print(f"   evidence: {evidence}")
        sys.exit(1)

    print("\nPASS: no blocking entries found")


if __name__ == "__main__":
    main()
