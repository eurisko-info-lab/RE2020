#!/usr/bin/env python3
"""Synchronize and validate local benchmark evidence files.

This script derives official benchmark case IDs from RE2020/RE2020.lean and
checks that RE2020/data/validation/cases contains matching JSON evidence files.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Sync/check benchmark evidence files")
    p.add_argument("--repo-root", default=".")
    p.add_argument("--re2020-source", default="RE2020/RE2020.lean")
    p.add_argument("--evidence-dir", default="RE2020/data/validation/cases")
    p.add_argument(
        "--ci",
        action="store_true",
        help="Deterministic check mode (equivalent to --fail-on-extra)",
    )
    p.add_argument(
        "--maintain",
        action="store_true",
        help="Maintainer mode (equivalent to --write-missing --normalize-existing)",
    )
    p.add_argument(
        "--write-missing",
        action="store_true",
        help="Create scaffold JSON files for missing official case IDs",
    )
    p.add_argument(
        "--fail-on-extra",
        action="store_true",
        help="Fail if evidence directory contains case files not present in benchmark suite",
    )
    p.add_argument(
        "--normalize-existing",
        action="store_true",
        help="Normalize existing files to required schema and reference values",
    )
    return p.parse_args()


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
    for _, source_doc, official_case_id, tolerance_profile, citation_id in row_re.findall(text):
        rows.append(
            {
                "sourceDoc": source_doc,
                "officialCaseId": official_case_id,
                "toleranceProfile": tolerance_profile,
                "citationId": citation_id,
            }
        )
    return rows


def build_scaffold_row(row: dict[str, str]) -> dict[str, Any]:
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    return {
        "officialCaseId": row["officialCaseId"],
        "reference": {
            "sourceDoc": row["sourceDoc"],
            "toleranceProfile": row["toleranceProfile"],
            "citationId": row["citationId"],
        },
        "provenance": {
            "capturedAt": now,
            "generatedBy": "scripts/sync_validation_evidence.py",
            "status": "scaffold",
        },
        "notes": "Local benchmark evidence scaffold. Replace with audited reproducibility details as needed.",
    }


def parse_json_file(path: Path) -> dict[str, Any] | None:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except json.JSONDecodeError:
        return None
    if not isinstance(raw, dict):
        return None
    return raw


def normalize_payload(raw: dict[str, Any] | None, row: dict[str, str]) -> dict[str, Any]:
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    data = dict(raw) if isinstance(raw, dict) else {}

    data["officialCaseId"] = row["officialCaseId"]

    reference_raw = data.get("reference")
    reference = dict(reference_raw) if isinstance(reference_raw, dict) else {}
    reference["sourceDoc"] = row["sourceDoc"]
    reference["toleranceProfile"] = row["toleranceProfile"]
    reference["citationId"] = row["citationId"]
    data["reference"] = reference

    provenance_raw = data.get("provenance")
    provenance = dict(provenance_raw) if isinstance(provenance_raw, dict) else {}
    if not isinstance(provenance.get("capturedAt"), str) or not provenance.get("capturedAt", "").strip():
        provenance["capturedAt"] = now
    if not isinstance(provenance.get("status"), str) or not provenance.get("status", "").strip():
        provenance["status"] = "present"
    if not isinstance(provenance.get("generatedBy"), str) or not provenance.get("generatedBy", "").strip():
        provenance["generatedBy"] = "scripts/sync_validation_evidence.py"
    data["provenance"] = provenance

    if not isinstance(data.get("notes"), str) or not data.get("notes", "").strip():
        data["notes"] = "Local benchmark evidence anchor for readiness-v2 reproducible artifacts gate."

    return data


def validate_required_schema(raw: dict[str, Any], expected_row: dict[str, str], filename_stem: str) -> list[str]:
    errors: list[str] = []

    official_case_id = raw.get("officialCaseId")
    if not isinstance(official_case_id, str) or not official_case_id.strip():
        errors.append("officialCaseId missing")
    elif official_case_id != filename_stem:
        errors.append("officialCaseId does not match filename")

    reference = raw.get("reference")
    if not isinstance(reference, dict):
        errors.append("reference missing")
        return errors

    for key in ("sourceDoc", "toleranceProfile", "citationId"):
        value = reference.get(key)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"reference.{key} missing")

    if isinstance(reference.get("sourceDoc"), str) and reference["sourceDoc"] != expected_row["sourceDoc"]:
        errors.append("reference.sourceDoc mismatch")
    if isinstance(reference.get("toleranceProfile"), str) and reference["toleranceProfile"] != expected_row["toleranceProfile"]:
        errors.append("reference.toleranceProfile mismatch")
    if isinstance(reference.get("citationId"), str) and reference["citationId"] != expected_row["citationId"]:
        errors.append("reference.citationId mismatch")

    provenance = raw.get("provenance")
    if not isinstance(provenance, dict):
        errors.append("provenance missing")
    else:
        if not isinstance(provenance.get("capturedAt"), str) or not provenance.get("capturedAt", "").strip():
            errors.append("provenance.capturedAt missing")
        if not isinstance(provenance.get("status"), str) or not provenance.get("status", "").strip():
            errors.append("provenance.status missing")

    notes = raw.get("notes")
    if not isinstance(notes, str) or not notes.strip():
        errors.append("notes missing")

    return errors


def main() -> None:
    args = parse_args()
    if args.ci and args.maintain:
        print("ERROR: --ci and --maintain are mutually exclusive")
        sys.exit(2)

    write_missing = args.write_missing or args.maintain
    normalize_existing = args.normalize_existing or args.maintain
    fail_on_extra = args.fail_on_extra or args.ci

    root = Path(args.repo_root).resolve()
    source_path = root / args.re2020_source
    evidence_dir = root / args.evidence_dir

    if not source_path.exists():
        print(f"ERROR: source file not found: {source_path}")
        sys.exit(2)

    source_text = source_path.read_text(encoding="utf-8")
    benchmark_rows = extract_benchmark_rows(source_text)
    if not benchmark_rows:
        print("ERROR: no benchmark reference rows found in RE2020 source")
        sys.exit(2)

    expected_map = {row["officialCaseId"]: row for row in benchmark_rows if row["officialCaseId"].strip()}
    expected_ids = set(expected_map.keys())

    evidence_dir.mkdir(parents=True, exist_ok=True)
    actual_files = sorted(evidence_dir.glob("*.json"))
    actual_ids = {p.stem for p in actual_files}

    missing = sorted(expected_ids - actual_ids)
    extra = sorted(actual_ids - expected_ids)

    created = 0
    if write_missing and missing:
        for cid in missing:
            out = evidence_dir / f"{cid}.json"
            payload = build_scaffold_row(expected_map[cid])
            out.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
            created += 1
        actual_files = sorted(evidence_dir.glob("*.json"))
        actual_ids = {p.stem for p in actual_files}
        missing = sorted(expected_ids - actual_ids)

    normalized = 0
    if normalize_existing:
        for cid in sorted(expected_ids):
            path = evidence_dir / f"{cid}.json"
            current = parse_json_file(path)
            payload = normalize_payload(current, expected_map[cid])
            new_content = json.dumps(payload, indent=2, ensure_ascii=True) + "\n"
            old_content = path.read_text(encoding="utf-8") if path.exists() else ""
            if old_content != new_content:
                path.write_text(new_content, encoding="utf-8")
                normalized += 1
        actual_files = sorted(evidence_dir.glob("*.json"))
        actual_ids = {p.stem for p in actual_files}
        missing = sorted(expected_ids - actual_ids)

    malformed: list[str] = []
    schema_errors: list[str] = []
    for path in actual_files:
        if path.stem not in expected_map:
            continue
        raw = parse_json_file(path)
        if raw is None:
            malformed.append(path.name)
            continue
        for error in validate_required_schema(raw, expected_map[path.stem], path.stem):
            schema_errors.append(f"{path.name}: {error}")

    print("Validation evidence sync")
    print(f"- source: {source_path}")
    print(f"- evidence dir: {evidence_dir}")
    print(f"- expected official cases: {len(expected_ids)}")
    print(f"- evidence files present: {len(actual_ids)}")
    print(f"- mode: {'ci' if args.ci else 'maintain' if args.maintain else 'custom'}")
    print(f"- created missing files: {created}")
    print(f"- normalized files: {normalized}")

    if missing:
        print(f"- missing evidence files: {', '.join(missing)}")
    if extra:
        print(f"- extra evidence files: {', '.join(extra)}")
    if malformed:
        print(f"- malformed JSON files: {', '.join(malformed)}")
    if schema_errors:
        print(f"- schema/reference errors: {', '.join(schema_errors)}")

    has_errors = bool(missing or malformed or schema_errors)
    if fail_on_extra and extra:
        has_errors = True

    if has_errors:
        print("FAIL: validation evidence is not synchronized")
        sys.exit(1)

    print("PASS: validation evidence is synchronized")


if __name__ == "__main__":
    main()
