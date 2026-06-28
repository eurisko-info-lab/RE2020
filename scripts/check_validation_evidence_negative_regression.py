#!/usr/bin/env python3
"""Negative regression check for validation evidence hardening.

This script temporarily corrupts one benchmark evidence file and verifies that:
1) evidence CI check fails (`sync_validation_evidence.py --ci`)
2) readiness scoring loses the reproducible-artifacts gate and drops below 100.

The modified file is always restored, even on failure.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run negative regression test for evidence hardening")
    p.add_argument("--repo-root", default=".")
    p.add_argument(
        "--case-id",
        default="RC-BUR-H3-01",
        help="Official case ID to corrupt temporarily",
    )
    return p.parse_args()


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True)


def main() -> None:
    args = parse_args()
    root = Path(args.repo_root).resolve()
    evidence_path = root / "RE2020" / "data" / "validation" / "cases" / f"{args.case_id}.json"
    json_out = root / "RE2020" / "compliance_readiness_score.negative.json"
    md_out = root / "RE2020" / "compliance_readiness_score.negative.md"

    if not evidence_path.exists():
        print(f"ERROR: evidence file not found: {evidence_path}")
        sys.exit(2)

    original_text = evidence_path.read_text(encoding="utf-8")

    try:
        data = json.loads(original_text)
        if not isinstance(data, dict):
            raise ValueError("evidence file top-level must be object")
        reference = data.get("reference")
        if not isinstance(reference, dict):
            raise ValueError("evidence file missing reference object")

        # Corrupt one required field so both sync CI and scorer artifact gate should fail.
        reference["citationId"] = "INTENTIONAL-NEGATIVE-REGRESSION"
        data["reference"] = reference
        evidence_path.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

        sync_result = run(["python3", "scripts/sync_validation_evidence.py", "--ci"], root)
        if sync_result.returncode == 0:
            print("FAIL: sync_validation_evidence --ci unexpectedly passed after corruption")
            print(sync_result.stdout)
            print(sync_result.stderr)
            sys.exit(1)

        score_result = run(
            [
                "python3",
                "scripts/compute_compliance_readiness_score.py",
                "--json-out",
                str(json_out.relative_to(root)),
                "--md-out",
                str(md_out.relative_to(root)),
            ],
            root,
        )
        if score_result.returncode != 0:
            print("FAIL: readiness scorer failed to execute during negative regression")
            print(score_result.stdout)
            print(score_result.stderr)
            sys.exit(1)

        payload = json.loads(json_out.read_text(encoding="utf-8"))
        overall = payload.get("overallScore")
        gates = payload.get("qualificationGates", {})
        artifact_gate = gates.get("reproducibleArtifacts", {}).get("passed")

        if artifact_gate is not False:
            print("FAIL: reproducibleArtifacts gate unexpectedly passed after corruption")
            sys.exit(1)
        if not isinstance(overall, (int, float)) or float(overall) >= 100.0:
            print(f"FAIL: overall score unexpectedly remained at 100 ({overall})")
            sys.exit(1)

        print("PASS: negative regression detected expected failures")
        print(f"- sync_ci_exit: {sync_result.returncode}")
        print(f"- overall_score_after_corruption: {overall}")
        print(f"- reproducible_artifacts_gate: {artifact_gate}")

    finally:
        evidence_path.write_text(original_text, encoding="utf-8")
        # Best effort cleanup of temporary negative artifacts.
        if json_out.exists():
            json_out.unlink()
        if md_out.exists():
            md_out.unlink()


if __name__ == "__main__":
    main()
