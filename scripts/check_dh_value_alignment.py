#!/usr/bin/env python3
"""Validate DH comfort-threshold values and IDs against baseline-v1."""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

TOL = 1e-9
EXPECTED = {
    "DH-COMFORT-LOW": (0.0, 26.0, 26.0),
    "DH-COMFORT-MID": (26.0, 28.0, 27.0),
    "DH-COMFORT-HIGH": (28.0, 1000.0, 28.0),
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate DH value alignment")
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
        r"\{\s*minRunningMean\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*maxRunningMean\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*comfortTemp\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*citation\s*:=\s*mkCitation\s*\"[^\"]+\"\s*\"([^\"]+)\"",
        re.S,
    )

    rows: dict[str, tuple[float, float, float]] = {}
    for mn, mx, c, tid in row_re.findall(text):
        if tid in EXPECTED:
            rows[tid] = (float(mn), float(mx), float(c))

    errs: list[str] = []
    for tid, (emn, emx, ec) in EXPECTED.items():
        if tid not in rows:
            errs.append(f"missing tableId '{tid}'")
            continue
        gmn, gmx, gc = rows[tid]
        if not math.isclose(gmn, emn, rel_tol=0.0, abs_tol=TOL):
            errs.append(f"{tid}: min drift (got {gmn}, expected {emn})")
        if not math.isclose(gmx, emx, rel_tol=0.0, abs_tol=TOL):
            errs.append(f"{tid}: max drift (got {gmx}, expected {emx})")
        if not math.isclose(gc, ec, rel_tol=0.0, abs_tol=TOL):
            errs.append(f"{tid}: comfort drift (got {gc}, expected {ec})")

    print("DH value-alignment guard")
    print(f"- source: {args.source}")
    print("- profile: baseline-v1")

    if errs:
        print(f"\nFAIL: {len(errs)} issue(s)")
        for e in errs:
            print(f"- {e}")
        sys.exit(1)

    print("\nPASS: DH thresholds and IDs match baseline-v1")


if __name__ == "__main__":
    main()
