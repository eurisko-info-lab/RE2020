#!/usr/bin/env python3
"""Shared parsing utilities for scenario traceability scripts."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any


CATEGORY_PATTERN = re.compile(r"BuildingCategory\.(MaisonIndividuelle|LogementCollectif|Bureau|EnseignementPrimaireSecondaire|Autre)")


def find_def_block(text: str, def_name: str) -> str | None:
    m = re.search(rf"def\s+{re.escape(def_name)}\b.*?:=", text)
    if not m:
        return None
    start = m.start()
    rest = text[start:]
    next_def = re.search(r"\ndef\s+", rest[1:])
    if not next_def:
        return rest
    return rest[: next_def.start() + 1]


def parse_float_field(block: str, field: str) -> float | None:
    m = re.search(rf"{re.escape(field)}\s*:=\s*([0-9]+(?:\.[0-9]+)?)", block)
    if not m:
        return None
    return float(m.group(1))


def parse_string_field(block: str, field: str) -> str | None:
    m = re.search(rf"{re.escape(field)}\s*:=\s*\"([^\"]+)\"", block)
    if not m:
        return None
    return m.group(1)


def parse_category_mapping(block: str) -> dict[str, str]:
    mapping: dict[str, str] = {}
    pending_categories: list[str] = []

    for raw_line in block.splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            continue

        cats = CATEGORY_PATTERN.findall(line)
        pending_categories.extend(cats)

        if "=>" in line:
            target = line.split("=>", 1)[1].strip().split()[0]
            if pending_categories:
                for c in pending_categories:
                    mapping[c] = target
                pending_categories = []

    return mapping


def extract_scenario_traceability(source_path: Path) -> dict[str, Any]:
    text = source_path.read_text(encoding="utf-8")

    end_use_profiles: dict[str, dict[str, float]] = {}
    for name in ["residentialEndUseProfile", "officeEndUseProfile", "teachingEndUseProfile"]:
        block = find_def_block(text, name)
        if not block:
            continue
        end_use_profiles[name] = {
            "dhwDailyNeedPerM2": parse_float_field(block, "dhwDailyNeedPerM2") or 0.0,
            "dhwStorageLossesPerM2": parse_float_field(block, "dhwStorageLossesPerM2") or 0.0,
            "auxiliaryOperatingHours": parse_float_field(block, "auxiliaryOperatingHours") or 0.0,
        }

    citations: dict[str, dict[str, str]] = {}
    citation_defs = [
        "residentialEndUseCitation",
        "officeEndUseCitation",
        "teachingEndUseCitation",
        "residentialScenarioCitation",
        "officeScenarioCitation",
        "teachingScenarioCitation",
    ]
    for name in citation_defs:
        block = find_def_block(text, name)
        if not block:
            continue
        citations[name] = {
            "sourceDoc": parse_string_field(block, "sourceDoc") or "",
            "sectionId": parse_string_field(block, "sectionId") or "",
            "tableId": parse_string_field(block, "tableId") or "",
            "articleRef": parse_string_field(block, "articleRef") or "",
            "equationId": parse_string_field(block, "equationId") or "",
            "version": parse_string_field(block, "version") or "",
            "effectiveDate": parse_string_field(block, "effectiveDate") or "",
        }

    mappings: dict[str, dict[str, str]] = {}
    for fn in ["getScenario", "getScenarioCitation", "getEndUseProfile", "getEndUseProfileCitation"]:
        block = find_def_block(text, fn)
        if not block:
            continue
        mappings[fn] = parse_category_mapping(block)

    return {
        "endUseProfiles": end_use_profiles,
        "citations": citations,
        "mappings": mappings,
    }
