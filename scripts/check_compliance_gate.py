#!/usr/bin/env python3
"""Run the RE2020 composite compliance gate.

This script orchestrates deterministic validation steps and fails fast on errors.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run_step(name: str, command: list[str], cwd: Path) -> None:
    print(f"\n== {name} ==")
    print("$ " + " ".join(command))
    result = subprocess.run(command, cwd=cwd)
    if result.returncode != 0:
        print(f"\nFAIL: {name} (exit code {result.returncode})")
        sys.exit(result.returncode)
    print(f"PASS: {name}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Run composite RE2020 compliance gate")
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root path (default: current directory)",
    )
    parser.add_argument(
        "--include-build",
        action="store_true",
        help="Also run lake build at the end",
    )
    parser.add_argument(
        "--strict-legal-catalog",
        action="store_true",
        help="Enforce strict legal catalog mode (no unused IDs, used IDs must be finalized)",
    )
    parser.add_argument(
        "--include-negative-regression",
        action="store_true",
        help="Run negative anti-gaming regression check for validation evidence",
    )
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()

    legal_catalog_command = ["python3", "scripts/check_legal_reference_catalog.py"]
    if args.strict_legal_catalog:
        legal_catalog_command.extend(["--fail-on-unused-catalog", "--require-finalized-used"])

    steps: list[tuple[str, list[str]]] = [
        (
            "Climate dataset validation",
            ["python3", "scripts/validate_climate_datasets.py"],
        ),
        (
            "Regulation table export",
            ["python3", "scripts/export_regulation_tables.py"],
        ),
        (
            "Usage factor traceability",
            ["python3", "scripts/check_usage_factor_traceability.py"],
        ),
        (
            "Usage factor value alignment",
            ["python3", "scripts/check_usage_factor_value_alignment.py"],
        ),
        (
            "Modulation traceability",
            ["python3", "scripts/check_modulation_traceability.py"],
        ),
        (
            "Modulation value alignment",
            ["python3", "scripts/check_modulation_value_alignment.py"],
        ),
        (
            "Bbio traceability",
            ["python3", "scripts/check_bbio_traceability.py"],
        ),
        (
            "Bbio value alignment",
            ["python3", "scripts/check_bbio_value_alignment.py"],
        ),
        (
            "Systems traceability",
            ["python3", "scripts/check_systems_traceability.py"],
        ),
        (
            "Systems value alignment",
            ["python3", "scripts/check_systems_value_alignment.py"],
        ),
        (
            "DH traceability",
            ["python3", "scripts/check_dh_traceability.py"],
        ),
        (
            "DH value alignment",
            ["python3", "scripts/check_dh_value_alignment.py"],
        ),
        (
            "Solar traceability",
            ["python3", "scripts/check_solar_traceability.py"],
        ),
        (
            "Solar value alignment",
            ["python3", "scripts/check_solar_value_alignment.py"],
        ),
        (
            "Validation reference traceability",
            ["python3", "scripts/check_validation_reference_traceability.py"],
        ),
        (
            "Validation evidence synchronization",
            ["python3", "scripts/sync_validation_evidence.py", "--ci"],
        ),
        (
            "Scenario profile traceability",
            ["python3", "scripts/check_scenario_profile_traceability.py"],
        ),
        (
            "Scenario profile export",
            ["python3", "scripts/export_scenario_profiles.py"],
        ),
        (
            "Scenario export consistency",
            ["python3", "scripts/check_scenario_export_consistency.py"],
        ),
        (
            "Scenario value alignment",
            ["python3", "scripts/check_scenario_value_alignment.py"],
        ),
        (
            "Lighting value alignment",
            ["python3", "scripts/check_lighting_value_alignment.py"],
        ),
        (
            "Legal reference catalog coverage",
            legal_catalog_command,
        ),
        (
            "Compliance readiness score",
            [
                "python3",
                "scripts/compute_compliance_readiness_score.py",
                "--json-out",
                "RE2020/compliance_readiness_score.json",
                "--md-out",
                "RE2020/compliance_readiness_score.md",
            ],
        ),
    ]

    if args.include_build:
        steps.append(("Lean build", ["lake", "build"]))

    if args.include_negative_regression:
        steps.append(
            (
                "Validation evidence negative regression",
                ["python3", "scripts/check_validation_evidence_negative_regression.py"],
            )
        )

    print("RE2020 composite compliance gate")
    print(f"- root: {root}")
    print(f"- include build: {'yes' if args.include_build else 'no'}")
    print(f"- strict legal catalog: {'yes' if args.strict_legal_catalog else 'no'}")
    print(f"- include negative regression: {'yes' if args.include_negative_regression else 'no'}")

    for name, command in steps:
        run_step(name, command, root)

    print("\nPASS: composite compliance gate completed")


if __name__ == "__main__":
    main()
