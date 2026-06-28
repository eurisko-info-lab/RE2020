#!/usr/bin/env python3
"""Validate Bbio weight values and table IDs against baseline-v1."""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

TOL = 1e-9
EXPECTED = {
    "heating_need": (2.0, "BBIO-W-HEAT"),
    "cooling_need": (2.0, "BBIO-W-COOL"),
    "lighting_need": (5.0, "BBIO-W-LIGHT"),
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate Bbio value alignment")
    p.add_argument("--source", default="RE2020/RegulationTables.lean")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    try:
        text = Path(args.source).read_text(encoding="utf-8")
    except Exception as exc:
        print(f"ERROR: cannot read {args.source}: {exc}")
        sys.exit(2)

    row_re = re.compile(
        r"\{\s*usage\s*:=\s*\"([^\"]+)\",\s*value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*citation\s*:=\s*mkCitation\s*\"[^\"]+\"\s*\"([^\"]+)\"",
        re.S,
    )
    rows = {u: (float(v), tid) for u, v, tid in row_re.findall(text) if u in EXPECTED}

    errs: list[str] = []
    for u, (ev, etid) in EXPECTED.items():
        if u not in rows:
            errs.append(f"missing usage '{u}'")
            continue
        gv, gtid = rows[u]
        if not math.isclose(gv, ev, rel_tol=0.0, abs_tol=TOL):
            errs.append(f"usage '{u}' value drift (got {gv}, expected {ev})")
        if gtid != etid:
            errs.append(f"usage '{u}' tableId drift (got '{gtid}', expected '{etid}')")

    print("Bbio value-alignment guard")
    print(f"- source: {args.source}")
    print("- profile: baseline-v1")

    if errs:
        print(f"\nFAIL: {len(errs)} issue(s)")
        for e in errs:
            print(f"- {e}")
        sys.exit(1)

    print("\nPASS: Bbio weights and IDs match baseline-v1")


if __name__ == "__main__":
    main()
