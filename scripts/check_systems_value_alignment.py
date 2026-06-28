#!/usr/bin/env python3
"""Validate systems convention values and IDs against baseline-v1."""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

TOL = 1e-9
EXPECTED_GENERATORS = {
    "SYS-GEN-GAS-COND": ("GasBoilerCondensing", 0.92, 0.90, 50.0, 1.0),
    "SYS-GEN-OIL": ("OilBoiler", 0.88, 0.85, 60.0, 1.0),
    "SYS-GEN-WOOD": ("WoodBoiler", 0.85, 0.82, 55.0, 1.0),
    "SYS-GEN-HP-AA": ("HeatPumpAirAir", 3.2, 2.8, 80.0, 2.3),
    "SYS-GEN-HP-AW": ("HeatPumpAirWater", 3.5, 3.0, 100.0, 2.3),
    "SYS-GEN-HP-WW": ("HeatPumpWaterWater", 4.2, 3.7, 110.0, 2.3),
    "SYS-GEN-DH": ("DistrictHeating", 0.95, 0.90, 30.0, 1.0),
    "SYS-GEN-ELEC": ("ElectricHeating", 1.0, 1.0, 20.0, 2.3),
}
EXPECTED_PARTLOAD = {
    "SYS-PLC-GAS-COND": ("GasBoilerCondensing", 0.80, 0.30, -0.10),
    "SYS-PLC-WOOD": ("WoodBoiler", 0.70, 0.40, -0.10),
    "SYS-PLC-HP-AA": ("HeatPumpAirAir", 0.60, 0.95, -0.55),
    "SYS-PLC-HP-AW": ("HeatPumpAirWater", 0.60, 0.95, -0.55),
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate systems value alignment")
    p.add_argument("--source", default="RE2020/Systems.lean")
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

    generator_re = re.compile(
        r"\{\s*genType\s*:=\s*\.([A-Za-z]+),\s*nominalEfficiency\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*seasonalPerformance\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*auxiliaryPower\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*primaryEnergyFactor\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*citation\s*:=\s*mkSystemCitation\s*\"[^\"]+\"\s*\"([^\"]+)\"",
        re.S,
    )
    got_gen: dict[str, tuple[str, float, float, float, float]] = {}
    for g, ne, sp, ap, pef, tid in generator_re.findall(text):
        if tid in EXPECTED_GENERATORS:
            got_gen[tid] = (g, float(ne), float(sp), float(ap), float(pef))

    for tid, (eg, ene, esp, eap, epef) in EXPECTED_GENERATORS.items():
        if tid not in got_gen:
            errs.append(f"missing tableId '{tid}'")
            continue
        gg, gne, gsp, gap, gpef = got_gen[tid]
        if gg != eg:
            errs.append(f"{tid}: generator drift (got {gg}, expected {eg})")
        if not close(gne, ene):
            errs.append(f"{tid}: nominalEfficiency drift (got {gne}, expected {ene})")
        if not close(gsp, esp):
            errs.append(f"{tid}: seasonalPerformance drift (got {gsp}, expected {esp})")
        if not close(gap, eap):
            errs.append(f"{tid}: auxiliaryPower drift (got {gap}, expected {eap})")
        if not close(gpef, epef):
            errs.append(f"{tid}: primaryEnergyFactor drift (got {gpef}, expected {epef})")

    partload_re = re.compile(
        r"\{\s*genType\s*:=\s*\.([A-Za-z]+),\s*a0\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*a1\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*a2\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*citation\s*:=\s*mkSystemCitation\s*\"[^\"]+\"\s*\"([^\"]+)\"",
        re.S,
    )
    got_part: dict[str, tuple[str, float, float, float]] = {}
    for g, a0, a1, a2, tid in partload_re.findall(text):
        if tid in EXPECTED_PARTLOAD:
            got_part[tid] = (g, float(a0), float(a1), float(a2))

    for tid, (eg, ea0, ea1, ea2) in EXPECTED_PARTLOAD.items():
        if tid not in got_part:
            errs.append(f"missing tableId '{tid}'")
            continue
        gg, ga0, ga1, ga2 = got_part[tid]
        if gg != eg:
            errs.append(f"{tid}: generator drift (got {gg}, expected {eg})")
        if not close(ga0, ea0):
            errs.append(f"{tid}: a0 drift (got {ga0}, expected {ea0})")
        if not close(ga1, ea1):
            errs.append(f"{tid}: a1 drift (got {ga1}, expected {ea1})")
        if not close(ga2, ea2):
            errs.append(f"{tid}: a2 drift (got {ga2}, expected {ea2})")

    print("Systems value-alignment guard")
    print(f"- source: {args.source}")
    print("- profile: baseline-v1")

    if errs:
        print(f"\nFAIL: {len(errs)} issue(s)")
        for e in errs:
            print(f"- {e}")
        sys.exit(1)

    print("\nPASS: systems conventions and IDs match baseline-v1")


if __name__ == "__main__":
    main()
