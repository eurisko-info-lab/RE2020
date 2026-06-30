#!/usr/bin/env python3
"""Validate primary/non-renewable usage factor values and IDs against baseline-v1."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

TOL = 1e-9

EXPECTED_PRIMARY = {
    "heating": (1.0, "PEF-HEATING"),
    "dhw": (2.3, "PEF-DHW"),
    "cooling": (2.3, "PEF-COOLING"),
    "lighting": (2.3, "PEF-LIGHTING"),
    "auxiliaries": (2.3, "PEF-AUX"),
}

EXPECTED_NON_REN = {
    "heating": (1.0, "PENR-HEATING"),
    "dhw": (2.3, "PENR-DHW"),
    "cooling": (2.3, "PENR-COOLING"),
    "lighting": (2.3, "PENR-LIGHTING"),
    "auxiliaries": (2.3, "PENR-AUX"),
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate usage factor value alignment")
    p.add_argument("--export", default="RE2020/data/regulation_tables_export.json")
    return p.parse_args()


def load(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"ERROR: cannot read {path}: {exc}")
        sys.exit(2)


def validate_table(name: str, rows: Any, expected: dict[str, tuple[float, str]]) -> list[str]:
    errs: list[str] = []
    if not isinstance(rows, list):
        return [f"{name}: expected list"]
    got: dict[str, tuple[float, str]] = {}
    for i, r in enumerate(rows):
        if not isinstance(r, dict):
            errs.append(f"{name}: row #{i} invalid")
            continue
        u = r.get("usage")
        v = r.get("value")
        c = r.get("citation")
        if not isinstance(u, str) or not isinstance(v, (int, float)) or not isinstance(c, dict):
            errs.append(f"{name}: row #{i} malformed")
            continue
        tid = c.get("tableId")
        if not isinstance(tid, str):
            errs.append(f"{name}: row #{i} missing tableId")
            continue
        if u in got:
            errs.append(f"{name}: duplicate usage '{u}'")
            continue
        got[u] = (float(v), tid)

    for u, (ev, etid) in expected.items():
        if u not in got:
            errs.append(f"{name}: missing usage '{u}'")
            continue
        gv, gtid = got[u]
        if not math.isclose(gv, ev, rel_tol=0.0, abs_tol=TOL):
            errs.append(f"{name}: usage '{u}' value drift (got {gv}, expected {ev})")
        if gtid != etid:
            errs.append(f"{name}: usage '{u}' tableId drift (got '{gtid}', expected '{etid}')")

    for u in got:
        if u not in expected:
            errs.append(f"{name}: unexpected usage '{u}'")
    return errs


def main() -> None:
    args = parse_args()
    data = load(Path(args.export))
    tables = data.get("tables", {})

    errs: list[str] = []
    errs += validate_table("primaryEnergyFactorTable", tables.get("primaryEnergyFactorTable"), EXPECTED_PRIMARY)
    errs += validate_table("nonRenewableEnergyFactorTable", tables.get("nonRenewableEnergyFactorTable"), EXPECTED_NON_REN)

    print("Usage factor value-alignment guard")
    print(f"- export: {args.export}")
    print("- profile: baseline-v1")

    if errs:
        print(f"\nFAIL: {len(errs)} issue(s)")
        for e in errs:
            print(f"- {e}")
        sys.exit(1)

    print("\nPASS: usage factor values and IDs match baseline-v1")


if __name__ == "__main__":
    main()
