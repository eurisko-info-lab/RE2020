#!/usr/bin/env python3
"""Export scenario/end-use profile traceability from Scenarios.lean to JSON."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from scenario_traceability_common import extract_scenario_traceability


def main() -> None:
    parser = argparse.ArgumentParser(description="Export scenario profile traceability to JSON")
    parser.add_argument("--input", default="RE2020/Scenarios.lean", help="Path to Scenarios.lean")
    parser.add_argument(
        "--output",
        default="RE2020/scenario_profiles_export.json",
        help="Path to write JSON export",
    )
    parser.add_argument(
        "--include-generated-at",
        action="store_true",
        help="Include generatedAtUtc timestamp (disabled by default for deterministic output)",
    )
    args = parser.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output)

    payload = {
        "metadata": {
            "source": str(in_path),
            "generator": "scripts/export_scenario_profiles.py",
        },
        "scenarioTraceability": extract_scenario_traceability(in_path),
    }

    if args.include_generated_at:
        payload["metadata"]["generatedAtUtc"] = datetime.now(timezone.utc).isoformat()

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    total_profiles = len(payload["scenarioTraceability"]["endUseProfiles"])
    total_citations = len(payload["scenarioTraceability"]["citations"])
    total_mappings = len(payload["scenarioTraceability"]["mappings"])
    print(
        f"Exported scenario traceability: profiles={total_profiles}, citations={total_citations}, mappings={total_mappings} -> {out_path}"
    )


if __name__ == "__main__":
    main()
