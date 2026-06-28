#!/usr/bin/env python3
"""Fail when exported citation IDs are not aligned with legal reference catalog."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate citation IDs against legal catalog")
    parser.add_argument(
        "--catalog",
        default="RE2020/legal_reference_catalog.json",
        help="Path to legal reference catalog JSON",
    )
    parser.add_argument(
        "--regulation-export",
        default="RE2020/regulation_tables_export.json",
        help="Path to regulation table export JSON",
    )
    parser.add_argument(
        "--scenario-export",
        default="RE2020/scenario_profiles_export.json",
        help="Path to scenario profile export JSON",
    )
    parser.add_argument(
        "--benchmark-source",
        default="RE2020/RE2020.lean",
        help="Path to RE2020 Lean source containing benchmark reference citation IDs",
    )
    parser.add_argument(
        "--fail-on-unused-catalog",
        action="store_true",
        help="Fail when catalog contains IDs not used by current exports",
    )
    parser.add_argument(
        "--allowed-statuses",
        default="provisional,finalized",
        help="Comma-separated allowed catalog statuses",
    )
    parser.add_argument(
        "--require-finalized-used",
        action="store_true",
        help="Fail when a used citation tableId has status different from 'finalized'",
    )
    return parser.parse_args()


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
            if isinstance(citation, dict):
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


def collect_benchmark_citation_ids(benchmark_source: Path) -> set[str]:
    try:
        text = benchmark_source.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"ERROR: file not found: {benchmark_source}")
        sys.exit(2)

    citation_re = re.compile(r"citationId\s*:=\s*\"([^\"]+)\"")
    return {cid for cid in citation_re.findall(text) if cid.strip()}


def collect_catalog_ids(
    catalog: dict[str, Any],
    allowed_statuses: set[str],
) -> tuple[set[str], dict[str, str], list[str]]:
    refs = catalog.get("references")
    if not isinstance(refs, list):
        print("ERROR: catalog has no 'references' list")
        sys.exit(2)

    ids: set[str] = set()
    statuses: dict[str, str] = {}
    errors: list[str] = []
    for i, ref in enumerate(refs, start=1):
        if not isinstance(ref, dict):
            errors.append(f"catalog row {i}: not an object")
            continue
        table_id = ref.get("tableId")
        section_id = ref.get("sectionId")
        status = ref.get("status")
        if not isinstance(table_id, str) or not table_id.strip():
            errors.append(f"catalog row {i}: missing tableId")
            continue
        if table_id in ids:
            errors.append(f"catalog row {i}: duplicate tableId '{table_id}'")
        ids.add(table_id)
        if not isinstance(section_id, str) or not section_id.strip():
            errors.append(f"catalog row {i}: tableId '{table_id}' missing sectionId")
        if not isinstance(status, str) or not status.strip():
            errors.append(f"catalog row {i}: tableId '{table_id}' missing status")
            continue
        normalized_status = status.strip().lower()
        if normalized_status not in allowed_statuses:
            errors.append(
                f"catalog row {i}: tableId '{table_id}' has disallowed status '{status}'"
            )
        statuses[table_id] = normalized_status
    return ids, statuses, errors


def main() -> None:
    args = parse_args()
    allowed_statuses = {
        s.strip().lower()
        for s in args.allowed_statuses.split(",")
        if s.strip()
    }
    if not allowed_statuses:
        print("ERROR: --allowed-statuses is empty")
        sys.exit(2)

    catalog = load_json(Path(args.catalog))
    reg = load_json(Path(args.regulation_export))
    scen = load_json(Path(args.scenario_export))
    benchmark_ids = collect_benchmark_citation_ids(Path(args.benchmark_source))

    catalog_ids, catalog_statuses, catalog_errors = collect_catalog_ids(catalog, allowed_statuses)
    used_ids = collect_regulation_table_ids(reg) | collect_scenario_table_ids(scen) | benchmark_ids

    missing_in_catalog = sorted(used_ids - catalog_ids)
    unused_in_catalog = sorted(catalog_ids - used_ids)

    print("Legal reference catalog guard")
    print(f"- catalog: {args.catalog}")
    print(f"- regulation export: {args.regulation_export}")
    print(f"- scenario export: {args.scenario_export}")
    print(f"- benchmark source: {args.benchmark_source}")
    print(f"- used citation IDs: {len(used_ids)}")
    print(f"- catalog IDs: {len(catalog_ids)}")
    print(f"- allowed statuses: {', '.join(sorted(allowed_statuses))}")

    errors = list(catalog_errors)
    for table_id in missing_in_catalog:
        errors.append(f"missing catalog entry for citation tableId '{table_id}'")
    if args.fail_on_unused_catalog:
        for table_id in unused_in_catalog:
            errors.append(f"unused catalog entry '{table_id}'")
    if args.require_finalized_used:
        for table_id in sorted(used_ids):
            status = catalog_statuses.get(table_id)
            if status is None:
                continue
            if status != "finalized":
                errors.append(
                    f"used citation tableId '{table_id}' is not finalized (status={status})"
                )

    if errors:
        print(f"\nFAIL: {len(errors)} issue(s) found")
        for err in errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: catalog covers all exported citation IDs")
    status_counts: dict[str, int] = {}
    for table_id in used_ids:
        status = catalog_statuses.get(table_id)
        if status is None:
            continue
        status_counts[status] = status_counts.get(status, 0) + 1
    if status_counts:
        summary = ", ".join(f"{k}={v}" for k, v in sorted(status_counts.items()))
        print(f"- used status distribution: {summary}")
    if unused_in_catalog:
        print(f"- note: {len(unused_in_catalog)} catalog IDs currently unused")


if __name__ == "__main__":
    main()
