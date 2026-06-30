#!/usr/bin/env python3
"""Compute an evidence-derived RE2020 compliance readiness score.

The score is derived from repository artifacts and guard wiring, not manual percentages.
Outputs are written as JSON and Markdown for CI publishing.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REQUIRED_GATE_CHECKS = [
    "scripts/check_usage_factor_traceability.py",
    "scripts/check_usage_factor_value_alignment.py",
    "scripts/check_modulation_traceability.py",
    "scripts/check_modulation_value_alignment.py",
    "scripts/check_regulation_export_legal_keys.py",
    "scripts/check_bbio_traceability.py",
    "scripts/check_bbio_value_alignment.py",
    "scripts/check_systems_traceability.py",
    "scripts/check_systems_value_alignment.py",
    "scripts/check_dh_traceability.py",
    "scripts/check_dh_value_alignment.py",
    "scripts/check_solar_traceability.py",
    "scripts/check_solar_value_alignment.py",
    "scripts/check_validation_reference_traceability.py",
    "scripts/sync_validation_evidence.py",
    "scripts/check_scenario_profile_traceability.py",
    "scripts/check_scenario_export_consistency.py",
    "scripts/check_scenario_export_legal_keys.py",
    "scripts/check_scenario_value_alignment.py",
    "scripts/check_lighting_value_alignment.py",
    "scripts/check_formal_approx_certificate.py",
    "scripts/check_formal_approx_certificate_drift.py",
    "scripts/check_legal_reference_catalog.py",
]

# Qualification thresholds for full-score eligibility.
MIN_BENCHMARK_CASES = 12
MIN_UNIQUE_OFFICIAL_CASES = 12
MIN_TOLERANCE_CALIBRATED_COVERAGE = 1.0
MIN_SOURCE_URI_COVERAGE = 1.0
MIN_SOURCE_DIGEST_COVERAGE = 1.0
MIN_OFFICIAL_DATASET_COVERAGE = 1.0

REQUIRED_MANIFEST_PROOF_FIELDS = [
    "sourceAuthority",
    "sourceLicense",
    "sourceUri",
    "sourceChecksum",
]

MIN_LOCAL_BENCHMARK_EVIDENCE_FILES = 12


def _parse_evidence_json(path: Path) -> dict[str, Any] | None:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    if not isinstance(raw, dict):
        return None
    return raw


def _validate_evidence_payload(
    payload: dict[str, Any],
    expected_official_case_id: str,
    expected_source_doc: str,
    expected_tolerance_profile: str,
    expected_citation_id: str,
) -> list[str]:
    issues: list[str] = []

    official_case_id = payload.get("officialCaseId")
    if not isinstance(official_case_id, str) or not official_case_id.strip():
        issues.append("officialCaseId missing")
    elif official_case_id != expected_official_case_id:
        issues.append("officialCaseId mismatch")

    reference = payload.get("reference")
    if not isinstance(reference, dict):
        issues.append("reference missing")
        return issues

    source_doc = reference.get("sourceDoc")
    tolerance_profile = reference.get("toleranceProfile")
    citation_id = reference.get("citationId")

    if not isinstance(source_doc, str) or not source_doc.strip():
        issues.append("reference.sourceDoc missing")
    elif source_doc != expected_source_doc:
        issues.append("reference.sourceDoc mismatch")

    if not isinstance(tolerance_profile, str) or not tolerance_profile.strip():
        issues.append("reference.toleranceProfile missing")
    elif tolerance_profile != expected_tolerance_profile:
        issues.append("reference.toleranceProfile mismatch")

    if not isinstance(citation_id, str) or not citation_id.strip():
        issues.append("reference.citationId missing")
    elif citation_id != expected_citation_id:
        issues.append("reference.citationId mismatch")

    provenance = payload.get("provenance")
    if not isinstance(provenance, dict):
        issues.append("provenance missing")
    else:
        captured_at = provenance.get("capturedAt")
        status = provenance.get("status")
        if not isinstance(captured_at, str) or not captured_at.strip():
            issues.append("provenance.capturedAt missing")
        if not isinstance(status, str) or not status.strip():
            issues.append("provenance.status missing")

    notes = payload.get("notes")
    if not isinstance(notes, str) or not notes.strip():
        issues.append("notes missing")

    return issues


@dataclass
class ComponentResult:
    key: str
    label: str
    weight: float
    score: float
    details: dict[str, Any]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Compute RE2020 readiness score from evidence")
    p.add_argument("--repo-root", default=".")
    p.add_argument("--gate-script", default="scripts/check_compliance_gate.py")
    p.add_argument("--manifest", default="RE2020/data/climate/manifest.json")
    p.add_argument("--catalog", default="RE2020/data/legal_reference_catalog.json")
    p.add_argument("--regulation-export", default="RE2020/data/regulation_tables_export.json")
    p.add_argument("--scenario-export", default="RE2020/data/scenario_profiles_export.json")
    p.add_argument("--re2020-source", default="RE2020/RE2020.lean")
    p.add_argument(
        "--benchmark-evidence-dir",
        default="RE2020/data/validation/cases",
        help="Directory containing local benchmark evidence files (<officialCaseId>.json)",
    )
    p.add_argument("--json-out", default="RE2020/data/compliance_readiness_score.json")
    p.add_argument("--md-out", default="RE2020/data/compliance_readiness_score.md")
    p.add_argument(
        "--min-score",
        type=float,
        default=None,
        help="Optional CI threshold. Exit non-zero if overall score is below this value.",
    )
    return p.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"ERROR: file not found: {path}")
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {path}: {exc}")
        sys.exit(2)
    if not isinstance(raw, dict):
        print(f"ERROR: expected top-level object in {path}")
        sys.exit(2)
    return raw


def collect_regulation_table_ids(reg: dict[str, Any]) -> set[str]:
    table_ids: set[str] = set()
    tables = reg.get("tables", {})
    if not isinstance(tables, dict):
        return table_ids
    for rows in tables.values():
        if not isinstance(rows, list):
            continue
        for row in rows:
            if not isinstance(row, dict):
                continue
            citation = row.get("citation")
            if not isinstance(citation, dict):
                continue
            table_id = citation.get("tableId")
            if isinstance(table_id, str) and table_id.strip():
                table_ids.add(table_id)
    return table_ids


def collect_scenario_table_ids(scen: dict[str, Any]) -> set[str]:
    table_ids: set[str] = set()
    trace = scen.get("scenarioTraceability")
    if not isinstance(trace, dict):
        return table_ids
    citations = trace.get("citations")
    if not isinstance(citations, dict):
        return table_ids
    for citation in citations.values():
        if not isinstance(citation, dict):
            continue
        table_id = citation.get("tableId")
        if isinstance(table_id, str) and table_id.strip():
            table_ids.add(table_id)
    return table_ids


def collect_catalog_statuses(catalog: dict[str, Any]) -> dict[str, str]:
    refs = catalog.get("references")
    if not isinstance(refs, list):
        return {}
    statuses: dict[str, str] = {}
    for ref in refs:
        if not isinstance(ref, dict):
            continue
        tid = ref.get("tableId")
        status = ref.get("status")
        if not isinstance(tid, str) or not tid.strip():
            continue
        if not isinstance(status, str) or not status.strip():
            continue
        statuses[tid] = status.strip().lower()
    return statuses


def extract_benchmark_rows(text: str) -> list[dict[str, str]]:
    row_re = re.compile(
        r"\{\s*caseId\s*:=\s*\"([^\"]+)\",\s*"
        r"reference\s*:=\s*\{\s*"
        r"sourceDoc\s*:=\s*\"([^\"]+)\",\s*"
        r"officialCaseId\s*:=\s*\"([^\"]+)\",\s*"
        r"toleranceProfile\s*:=\s*\"([^\"]+)\",\s*"
        r"citationId\s*:=\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for case_id, source_doc, official_case_id, tolerance_profile, citation_id in row_re.findall(text):
        rows.append(
            {
                "caseId": case_id,
                "sourceDoc": source_doc,
                "officialCaseId": official_case_id,
                "toleranceProfile": tolerance_profile,
                "citationId": citation_id,
            }
        )
    return rows


def is_uri_like(value: str) -> bool:
    return value.startswith("http://") or value.startswith("https://")


def is_official_profile(value: str) -> bool:
    return value.startswith("official-") or value.startswith("cstb-")


def has_digest_marker(value: str) -> bool:
    v = value.lower()
    return "sha256=" in v or "checksum=" in v


def is_calibrated_tolerance_profile(value: str) -> bool:
    return re.match(r"^official-cstb-cal-v[0-9]+$", value.strip().lower()) is not None


def component_gate_wiring(gate_script_text: str) -> ComponentResult:
    found = [s for s in REQUIRED_GATE_CHECKS if s in gate_script_text]
    ratio = len(found) / len(REQUIRED_GATE_CHECKS) if REQUIRED_GATE_CHECKS else 0.0
    return ComponentResult(
        key="guard_wiring_coverage",
        label="Guard Wiring Coverage",
        weight=30.0,
        score=100.0 * ratio,
        details={
            "requiredChecks": len(REQUIRED_GATE_CHECKS),
            "foundChecks": len(found),
            "missingChecks": [s for s in REQUIRED_GATE_CHECKS if s not in gate_script_text],
        },
    )


def component_catalog_finalization(
    used_table_ids: set[str],
    benchmark_citation_ids: set[str],
    catalog_statuses: dict[str, str],
) -> ComponentResult:
    required_ids = used_table_ids | benchmark_citation_ids
    if not required_ids:
        return ComponentResult(
            key="citation_catalog_finalization",
            label="Citation Catalog Finalization",
            weight=30.0,
            score=0.0,
            details={"requiredIds": 0, "finalizedIds": 0, "missingInCatalog": []},
        )

    finalized = 0
    missing: list[str] = []
    non_finalized: list[str] = []
    for tid in sorted(required_ids):
        status = catalog_statuses.get(tid)
        if status is None:
            missing.append(tid)
            continue
        if status == "finalized":
            finalized += 1
        else:
            non_finalized.append(f"{tid}:{status}")

    ratio = finalized / len(required_ids)
    return ComponentResult(
        key="citation_catalog_finalization",
        label="Citation Catalog Finalization",
        weight=30.0,
        score=100.0 * ratio,
        details={
            "requiredIds": len(required_ids),
            "finalizedIds": finalized,
            "missingInCatalog": missing,
            "nonFinalized": non_finalized,
        },
    )


def component_official_provenance(manifest: dict[str, Any], benchmark_rows: list[dict[str, str]]) -> ComponentResult:
    dataset_version = manifest.get("datasetVersion")
    is_official_dataset = isinstance(dataset_version, str) and is_official_profile(dataset_version)

    total_cases = len(benchmark_rows)
    uri_count = 0
    digest_count = 0
    official_profile_count = 0
    calibrated_profile_count = 0
    for row in benchmark_rows:
        src = row["sourceDoc"]
        tol = row["toleranceProfile"]
        if is_uri_like(src):
            uri_count += 1
        if has_digest_marker(src):
            digest_count += 1
        if is_official_profile(tol):
            official_profile_count += 1
        if is_calibrated_tolerance_profile(tol):
            calibrated_profile_count += 1

    case_denom = total_cases if total_cases > 0 else 1
    source_uri_ratio = uri_count / case_denom
    digest_ratio = digest_count / case_denom
    tolerance_official_ratio = official_profile_count / case_denom
    tolerance_calibrated_ratio = calibrated_profile_count / case_denom

    manifest_proof = {
        field: manifest.get(field)
        for field in REQUIRED_MANIFEST_PROOF_FIELDS
    }
    manifest_proof_present = all(
        isinstance(v, str) and v.strip() for v in manifest_proof.values()
    )

    # Weighted inside component: dataset 30%, manifest proof 20%, source URI 20%, digest 15%, tolerance official 10%, tolerance calibrated 5%
    score = (
        30.0 * (1.0 if is_official_dataset else 0.0)
        + 20.0 * (1.0 if manifest_proof_present else 0.0)
        + 20.0 * source_uri_ratio
        + 15.0 * digest_ratio
        + 10.0 * tolerance_official_ratio
        + 5.0 * tolerance_calibrated_ratio
    )

    return ComponentResult(
        key="official_source_provenance",
        label="Official Source Provenance",
        weight=25.0,
        score=score,
        details={
            "datasetVersion": dataset_version,
            "datasetVersionIsOfficial": is_official_dataset,
            "benchmarkCaseCount": total_cases,
            "sourceUriCount": uri_count,
            "sourceDigestCount": digest_count,
            "officialToleranceProfileCount": official_profile_count,
            "calibratedToleranceProfileCount": calibrated_profile_count,
            "manifestProofFields": manifest_proof,
            "manifestProofPresent": manifest_proof_present,
        },
    )


def component_benchmark_rigor(benchmark_rows: list[dict[str, str]]) -> ComponentResult:
    total_cases = len(benchmark_rows)
    if total_cases == 0:
        return ComponentResult(
            key="benchmark_reference_rigor",
            label="Benchmark Reference Rigor",
            weight=15.0,
            score=0.0,
            details={"caseCount": 0, "uniqueOfficialCaseIds": 0},
        )

    unique_official = len({r["officialCaseId"] for r in benchmark_rows if r["officialCaseId"].strip()})
    non_placeholder_source = sum(
        1 for r in benchmark_rows if r["sourceDoc"].strip() and "reference cases dataset" not in r["sourceDoc"].lower()
    )

    case_count_score = min(total_cases / 4.0, 1.0)
    unique_score = unique_official / total_cases
    source_score = non_placeholder_source / total_cases

    score = 100.0 * (0.40 * case_count_score + 0.35 * unique_score + 0.25 * source_score)

    return ComponentResult(
        key="benchmark_reference_rigor",
        label="Benchmark Reference Rigor",
        weight=15.0,
        score=score,
        details={
            "caseCount": total_cases,
            "uniqueOfficialCaseIds": unique_official,
            "nonPlaceholderSourceDocs": non_placeholder_source,
        },
    )


def weighted_overall(components: list[ComponentResult]) -> float:
    total_weight = sum(c.weight for c in components)
    if total_weight <= 0.0:
        return 0.0
    return sum((c.score * c.weight) for c in components) / total_weight


def qualification_gates(
    manifest: dict[str, Any],
    benchmark_rows: list[dict[str, str]],
    benchmark_evidence_dir: Path,
) -> dict[str, Any]:
    total_cases = len(benchmark_rows)
    unique_official = len({r["officialCaseId"] for r in benchmark_rows if r["officialCaseId"].strip()})

    case_denom = total_cases if total_cases > 0 else 1
    uri_ratio = sum(1 for r in benchmark_rows if is_uri_like(r["sourceDoc"])) / case_denom
    digest_ratio = sum(1 for r in benchmark_rows if has_digest_marker(r["sourceDoc"])) / case_denom
    calibrated_ratio = sum(1 for r in benchmark_rows if is_calibrated_tolerance_profile(r["toleranceProfile"])) / case_denom

    dataset_version = manifest.get("datasetVersion")
    official_dataset_ratio = 1.0 if isinstance(dataset_version, str) and is_official_profile(dataset_version) else 0.0
    manifest_proof_present = all(
        isinstance(manifest.get(field), str) and manifest.get(field).strip()
        for field in REQUIRED_MANIFEST_PROOF_FIELDS
    )

    benchmark_gate = total_cases >= MIN_BENCHMARK_CASES and unique_official >= MIN_UNIQUE_OFFICIAL_CASES
    official_source_gate = (
        official_dataset_ratio >= MIN_OFFICIAL_DATASET_COVERAGE
        and manifest_proof_present
        and uri_ratio >= MIN_SOURCE_URI_COVERAGE
        and digest_ratio >= MIN_SOURCE_DIGEST_COVERAGE
    )
    tolerance_gate = calibrated_ratio >= MIN_TOLERANCE_CALIBRATED_COVERAGE

    expected_by_case_id: dict[str, dict[str, str]] = {}
    for r in benchmark_rows:
        cid = r["officialCaseId"].strip()
        if not cid:
            continue
        expected_by_case_id[cid] = r

    missing_evidence_files: list[str] = []
    invalid_evidence_files: list[str] = []
    valid_local_files: list[str] = []
    for cid, row in sorted(expected_by_case_id.items()):
        evidence_path = benchmark_evidence_dir / f"{cid}.json"
        if not evidence_path.exists():
            missing_evidence_files.append(evidence_path.name)
            continue
        payload = _parse_evidence_json(evidence_path)
        if payload is None:
            invalid_evidence_files.append(f"{evidence_path.name}: invalid-json")
            continue
        issues = _validate_evidence_payload(
            payload,
            expected_official_case_id=cid,
            expected_source_doc=row["sourceDoc"],
            expected_tolerance_profile=row["toleranceProfile"],
            expected_citation_id=row["citationId"],
        )
        if issues:
            invalid_evidence_files.append(f"{evidence_path.name}: {','.join(issues)}")
            continue
        valid_local_files.append(evidence_path.name)

    artifact_gate = (
        len(valid_local_files) >= MIN_LOCAL_BENCHMARK_EVIDENCE_FILES
        and not missing_evidence_files
        and not invalid_evidence_files
    )

    gates = {
        "benchmarkCorpus": {
            "passed": benchmark_gate,
            "requiredMinCases": MIN_BENCHMARK_CASES,
            "requiredMinUniqueOfficialCases": MIN_UNIQUE_OFFICIAL_CASES,
            "actualCases": total_cases,
            "actualUniqueOfficialCases": unique_official,
        },
        "officialSourceProof": {
            "passed": official_source_gate,
            "requiredDatasetCoverage": MIN_OFFICIAL_DATASET_COVERAGE,
            "requiredSourceUriCoverage": MIN_SOURCE_URI_COVERAGE,
            "requiredSourceDigestCoverage": MIN_SOURCE_DIGEST_COVERAGE,
            "actualDatasetCoverage": official_dataset_ratio,
            "actualSourceUriCoverage": round(uri_ratio, 4),
            "actualSourceDigestCoverage": round(digest_ratio, 4),
            "manifestProofPresent": manifest_proof_present,
            "requiredManifestProofFields": REQUIRED_MANIFEST_PROOF_FIELDS,
        },
        "toleranceCalibration": {
            "passed": tolerance_gate,
            "requiredCalibratedCoverage": MIN_TOLERANCE_CALIBRATED_COVERAGE,
            "actualCalibratedCoverage": round(calibrated_ratio, 4),
            "requiredPattern": "official-cstb-cal-vN",
        },
        "reproducibleArtifacts": {
            "passed": artifact_gate,
            "requiredLocalEvidenceFiles": MIN_LOCAL_BENCHMARK_EVIDENCE_FILES,
            "actualLocalEvidenceFiles": len(valid_local_files),
            "evidenceDirectory": str(benchmark_evidence_dir),
            "missingEvidenceFiles": missing_evidence_files,
            "invalidEvidenceFiles": invalid_evidence_files,
        },
    }
    gates["passedCount"] = sum(1 for g in (benchmark_gate, official_source_gate, tolerance_gate, artifact_gate) if g)
    gates["totalCount"] = 4
    gates["allPassed"] = gates["passedCount"] == gates["totalCount"]
    return gates


def apply_hard_cap(raw_score: float, gates: dict[str, Any]) -> tuple[float, float]:
    passed = gates["passedCount"]
    # 0/4 -> 50 cap, 1/4 -> 65 cap, 2/4 -> 75 cap, 3/4 -> 85 cap, 4/4 -> 100 cap
    ladder = {0: 50.0, 1: 65.0, 2: 75.0, 3: 85.0, 4: 100.0}
    cap = ladder.get(passed, 50.0)
    return min(raw_score, cap), cap


def to_markdown(overall: float, raw: float, cap: float, components: list[ComponentResult], model_version: str, gates: dict[str, Any]) -> str:
    lines = [
        "# RE2020 Compliance Readiness Score",
        "",
        f"- Model: {model_version}",
        f"- Overall score: {overall:.1f} / 100",
        f"- Raw weighted score (before hard cap): {raw:.1f} / 100",
        f"- Hard cap from qualification gates: {cap:.1f} / 100",
        "",
        "## Qualification Gates",
        "",
        f"- Benchmark corpus gate: {'PASS' if gates['benchmarkCorpus']['passed'] else 'FAIL'}",
        f"- Official source proof gate: {'PASS' if gates['officialSourceProof']['passed'] else 'FAIL'}",
        f"- Tolerance calibration gate: {'PASS' if gates['toleranceCalibration']['passed'] else 'FAIL'}",
        f"- Reproducible artifacts gate: {'PASS' if gates['reproducibleArtifacts']['passed'] else 'FAIL'}",
        "",
        "## Components",
        "",
        "| Component | Weight | Score | Weighted Contribution |",
        "|---|---:|---:|---:|",
    ]
    for c in components:
        contrib = c.score * (c.weight / 100.0)
        lines.append(f"| {c.label} | {c.weight:.1f}% | {c.score:.1f} | {contrib:.1f} |")
    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- This score is computed from repository evidence and guard wiring.",
            "- It is deterministic for a given repository state and scoring model version.",
            "- A score of 100 requires all qualification gates to pass.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    root = Path(args.repo_root).resolve()

    gate_script_path = root / args.gate_script
    manifest_path = root / args.manifest
    catalog_path = root / args.catalog
    regulation_export_path = root / args.regulation_export
    scenario_export_path = root / args.scenario_export
    re2020_source_path = root / args.re2020_source
    benchmark_evidence_dir = root / args.benchmark_evidence_dir
    json_out_path = root / args.json_out
    md_out_path = root / args.md_out

    try:
        gate_script_text = gate_script_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"ERROR: file not found: {gate_script_path}")
        sys.exit(2)

    manifest = load_json(manifest_path)
    catalog = load_json(catalog_path)
    regulation = load_json(regulation_export_path)
    scenario = load_json(scenario_export_path)

    try:
        re2020_text = re2020_source_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"ERROR: file not found: {re2020_source_path}")
        sys.exit(2)

    benchmark_rows = extract_benchmark_rows(re2020_text)
    benchmark_citation_ids = {r["citationId"] for r in benchmark_rows if r["citationId"].strip()}

    used_table_ids = collect_regulation_table_ids(regulation) | collect_scenario_table_ids(scenario)
    catalog_statuses = collect_catalog_statuses(catalog)

    components = [
        component_gate_wiring(gate_script_text),
        component_catalog_finalization(used_table_ids, benchmark_citation_ids, catalog_statuses),
        component_official_provenance(manifest, benchmark_rows),
        component_benchmark_rigor(benchmark_rows),
    ]

    raw_overall = weighted_overall(components)
    gates = qualification_gates(manifest, benchmark_rows, benchmark_evidence_dir)
    overall, hard_cap = apply_hard_cap(raw_overall, gates)
    model_version = "readiness-v2"

    payload = {
        "metadata": {
            "modelVersion": model_version,
            "computedAt": datetime.now(timezone.utc).isoformat(),
            "repoRoot": str(root),
        },
        "overallScore": round(overall, 2),
        "rawWeightedScore": round(raw_overall, 2),
        "hardCap": round(hard_cap, 2),
        "qualificationGates": gates,
        "components": [
            {
                "key": c.key,
                "label": c.label,
                "weight": c.weight,
                "score": round(c.score, 2),
                "weightedContribution": round(c.score * (c.weight / 100.0), 2),
                "details": c.details,
            }
            for c in components
        ],
    }

    json_out_path.parent.mkdir(parents=True, exist_ok=True)
    json_out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    md_out_path.write_text(
        to_markdown(overall, raw_overall, hard_cap, components, model_version, gates),
        encoding="utf-8",
    )

    print("Compliance readiness score")
    print(f"- model: {model_version}")
    print(f"- overall: {overall:.1f}/100")
    print(f"- raw weighted: {raw_overall:.1f}/100")
    print(f"- hard cap: {hard_cap:.1f}/100")
    print(f"- qualification gates passed: {gates['passedCount']}/{gates['totalCount']}")
    print(f"- json: {json_out_path}")
    print(f"- markdown: {md_out_path}")

    if args.min_score is not None and overall < args.min_score:
        print(f"\nFAIL: score {overall:.1f} is below required threshold {args.min_score:.1f}")
        sys.exit(1)

    print("PASS: readiness score computed")


if __name__ == "__main__":
    main()
