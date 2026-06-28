#!/usr/bin/env python3
"""Validate solar convention values and IDs against baseline-v1."""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

TOL = 1e-9
EXPECTED_SOLAR = {
    "SOL-CONV-ALBEDO": ("default_albedo", 0.2),
    "SOL-CONV-I0": ("extraterrestrial_irradiance", 1367.0),
    "SOL-CONV-LAT": ("default_latitude_france", 46.0),
    "SOL-CONV-VG": ("variable_g_reduction_factor", 0.55),
}
EXPECTED_PEREZ = {
    "SOL-PEREZ-BIN-01": (0.0, 1.065, 0.95, 0.05),
    "SOL-PEREZ-BIN-02": (1.065, 1.23, 0.90, 0.00),
    "SOL-PEREZ-BIN-03": (1.23, 1.5, 0.85, -0.05),
    "SOL-PEREZ-BIN-04": (1.5, 1.95, 0.80, -0.10),
    "SOL-PEREZ-BIN-05": (1.95, 2.8, 0.75, -0.15),
    "SOL-PEREZ-BIN-06": (2.8, 4.5, 0.65, -0.25),
    "SOL-PEREZ-BIN-07": (4.5, 6.2, 0.55, -0.38),
    "SOL-PEREZ-BIN-08": (6.2, 1000.0, 0.41, -0.55),
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate solar value alignment")
    p.add_argument("--source", default="RE2020/Solar.lean")
    return p.parse_args()


def close(a: float, b: float) -> bool:
    return math.isclose(a, b, rel_tol=0.0, abs_tol=TOL)


def main() -> None:
    args = parse_args()
    try:
        text = Path(args.source).read_text(encoding="utf-8")
    except Exception as exc:
        print(f"ERROR: cannot read {args.source}: {exc}")
        sys.exit(2)

    errs: list[str] = []

    conv_re = re.compile(
        r"\{\s*key\s*:=\s*\"([^\"]+)\",\s*value\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*citation\s*:=\s*mkSolarCitation\s*\"[^\"]+\"\s*\"([^\"]+)\"",
        re.S,
    )
    got_conv: dict[str, tuple[str, float]] = {}
    for key, value, tid in conv_re.findall(text):
        if tid in EXPECTED_SOLAR:
            got_conv[tid] = (key, float(value))

    for tid, (ekey, ev) in EXPECTED_SOLAR.items():
        if tid not in got_conv:
            errs.append(f"missing tableId '{tid}'")
            continue
        gkey, gv = got_conv[tid]
        if gkey != ekey:
            errs.append(f"{tid}: key drift (got '{gkey}', expected '{ekey}')")
        if not close(gv, ev):
            errs.append(f"{tid}: value drift (got {gv}, expected {ev})")

    perez_re = re.compile(
        r"\{\s*minEpsilon\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*maxEpsilon\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*f1\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*f2\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*citation\s*:=\s*mkSolarCitation\s*\"[^\"]+\"\s*\"([^\"]+)\"",
        re.S,
    )
    got_perez: dict[str, tuple[float, float, float, float]] = {}
    for min_eps, max_eps, f1, f2, tid in perez_re.findall(text):
        if tid in EXPECTED_PEREZ:
            got_perez[tid] = (float(min_eps), float(max_eps), float(f1), float(f2))

    for tid, (emin, emax, ef1, ef2) in EXPECTED_PEREZ.items():
        if tid not in got_perez:
            errs.append(f"missing tableId '{tid}'")
            continue
        gmin, gmax, gf1, gf2 = got_perez[tid]
        if not close(gmin, emin):
            errs.append(f"{tid}: minEpsilon drift (got {gmin}, expected {emin})")
        if not close(gmax, emax):
            errs.append(f"{tid}: maxEpsilon drift (got {gmax}, expected {emax})")
        if not close(gf1, ef1):
            errs.append(f"{tid}: f1 drift (got {gf1}, expected {ef1})")
        if not close(gf2, ef2):
            errs.append(f"{tid}: f2 drift (got {gf2}, expected {ef2})")

    print("Solar value-alignment guard")
    print(f"- source: {args.source}")
    print("- profile: baseline-v1")

    if errs:
        print(f"\nFAIL: {len(errs)} issue(s)")
        for e in errs:
            print(f"- {e}")
        sys.exit(1)

    print("\nPASS: solar conventions and IDs match baseline-v1")


if __name__ == "__main__":
    main()
