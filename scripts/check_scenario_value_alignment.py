#!/usr/bin/env python3
"""Validate scenario end-use values and citation IDs against baseline-v1."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

TOL = 1e-9
EXPECTED_ENDUSE = {
    "residentialEndUseProfile": {
        "dhwDailyNeedPerM2": 0.055,
        "dhwStorageLossesPerM2": 0.8,
        "auxiliaryOperatingHours": 2100.0,
        "tableId": "SCEN-ENDUSE-RES",
    },
    "officeEndUseProfile": {
        "dhwDailyNeedPerM2": 0.015,
        "dhwStorageLossesPerM2": 0.35,
        "auxiliaryOperatingHours": 2600.0,
        "tableId": "SCEN-ENDUSE-OFF",
    },
    "teachingEndUseProfile": {
        "dhwDailyNeedPerM2": 0.02,
        "dhwStorageLossesPerM2": 0.45,
        "auxiliaryOperatingHours": 2350.0,
        "tableId": "SCEN-ENDUSE-TEACH",
    },
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate scenario value alignment")
    p.add_argument("--export", default="RE2020/scenario_profiles_export.json")
    return p.parse_args()


def close(a: float, b: float) -> bool:
    return math.isclose(a, b, rel_tol=0.0, abs_tol=TOL)


def main() -> None:
    args = parse_args()
    try:
        data = json.loads(Path(args.export).read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"ERROR: cannot read {args.export}: {exc}")
        sys.exit(2)

    trace = data.get("scenarioTraceability", {})
    profiles = trace.get("endUseProfiles", {})
    citations = trace.get("citations", {})

    errs: list[str] = []
    for key, expected in EXPECTED_ENDUSE.items():
        got = profiles.get(key)
        if not isinstance(got, dict):
            errs.append(f"missing profile '{key}'")
            continue

        for fld in ("dhwDailyNeedPerM2", "dhwStorageLossesPerM2", "auxiliaryOperatingHours"):
            gv = got.get(fld)
            ev = expected[fld]
            if not isinstance(gv, (int, float)):
                errs.append(f"{key}: missing numeric field '{fld}'")
                continue
            if not close(float(gv), float(ev)):
                errs.append(f"{key}: {fld} drift (got {gv}, expected {ev})")

        citation_key = key.replace("Profile", "Citation")
        c = citations.get(citation_key)
        if not isinstance(c, dict):
            errs.append(f"missing citation '{citation_key}'")
            continue
        tid = c.get("tableId")
        if tid != expected["tableId"]:
            errs.append(
                f"{citation_key}: tableId drift (got '{tid}', expected '{expected['tableId']}')"
            )

    print("Scenario value-alignment guard")
    print(f"- export: {args.export}")
    print("- profile: baseline-v1")

    if errs:
        print(f"\nFAIL: {len(errs)} issue(s)")
        for e in errs:
            print(f"- {e}")
        sys.exit(1)

    print("\nPASS: scenario end-use values and IDs match baseline-v1")


if __name__ == "__main__":
    main()
