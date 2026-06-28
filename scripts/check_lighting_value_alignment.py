#!/usr/bin/env python3
"""Validate lighting parameter values and IDs against baseline-v1."""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

TOL = 1e-9
EXPECTED = {
    "LIGHT-PARAM-MI": ("MaisonIndividuelle", 5.5, 2.7, 1700.0),
    "LIGHT-PARAM-LC": ("LogementCollectif", 5.0, 2.6, 1800.0),
    "LIGHT-PARAM-BUR": ("Bureau", 8.0, 2.5, 2000.0),
    "LIGHT-PARAM-ENS": ("EnseignementPrimaireSecondaire", 7.0, 2.8, 1850.0),
    "LIGHT-PARAM-AUT": ("Autre", 7.5, 2.4, 1900.0),
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate lighting value alignment")
    p.add_argument("--source", default="RE2020/Lighting.lean")
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

    row_re = re.compile(
        r"\{\s*category\s*:=\s*\.([A-Za-z]+),\s*params\s*:=\s*\{\s*installedPowerDensity\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*daylightFactor\s*:=\s*([0-9]+(?:\.[0-9]+)?),[\s\S]*?operatingHours\s*:=\s*([0-9]+(?:\.[0-9]+)?)[\s\S]*?tableId\s*:=\s*\"([^\"]+)\"",
        re.S,
    )

    got: dict[str, tuple[str, float, float, float]] = {}
    for cat, ipd, dlf, oph, tid in row_re.findall(text):
        if tid in EXPECTED:
            got[tid] = (cat, float(ipd), float(dlf), float(oph))

    errs: list[str] = []
    for tid, (ecat, eipd, edlf, eoph) in EXPECTED.items():
        if tid not in got:
            errs.append(f"missing tableId '{tid}'")
            continue
        gcat, gipd, gdlf, goph = got[tid]
        if gcat != ecat:
            errs.append(f"{tid}: category drift (got {gcat}, expected {ecat})")
        if not close(gipd, eipd):
            errs.append(f"{tid}: installedPowerDensity drift (got {gipd}, expected {eipd})")
        if not close(gdlf, edlf):
            errs.append(f"{tid}: daylightFactor drift (got {gdlf}, expected {edlf})")
        if not close(goph, eoph):
            errs.append(f"{tid}: operatingHours drift (got {goph}, expected {eoph})")

    print("Lighting value-alignment guard")
    print(f"- source: {args.source}")
    print("- profile: baseline-v1")

    if errs:
        print(f"\nFAIL: {len(errs)} issue(s)")
        for e in errs:
            print(f"- {e}")
        sys.exit(1)

    print("\nPASS: lighting values and IDs match baseline-v1")


if __name__ == "__main__":
    main()
