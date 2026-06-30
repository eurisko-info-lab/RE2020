#!/usr/bin/env python3
"""Export RE2020 regulation coefficient tables from Lean source to JSON.

This script parses RE2020/RegulationTables.lean and emits a machine-readable
snapshot for legal review and coefficient diffing.
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


def _extract_version(text: str) -> str:
    m = re.search(r'def\s+modulationTableVersion\s*:\s*String\s*:=\s*"([^"]+)"', text)
    if not m:
        raise ValueError("Could not find modulationTableVersion")
    return m.group(1)


def _extract_zone_entries(text: str) -> list[dict[str, object]]:
    pattern = re.compile(
        r"\{\s*zone\s*:=\s*\.(\w+),\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for zone, value, section, table_id, article_ref in pattern.findall(text):
        rows.append(
            {
                "zone": zone,
                "value": float(value),
                "citation": {
                    "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                    "sectionId": section,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": "",
                    "version": "2026-06-27",
                    "effectiveDate": "2026-06-27",
                },
            }
        )
    return rows


def _extract_category_entries(text: str, table_name: str) -> list[dict[str, object]]:
    table_re = re.compile(rf"def\s+{re.escape(table_name)}\s*:\s*List\s+CategoryCoefficient\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*category\s*:=\s*\.(\w+),\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for category, value, section, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "category": category,
                "value": float(value),
                "citation": {
                    "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                    "sectionId": section,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": "",
                    "version": "2026-06-27",
                    "effectiveDate": "2026-06-27",
                },
            }
        )
    return rows


def _extract_area_entries(text: str, table_name: str) -> list[dict[str, object]]:
    table_re = re.compile(rf"def\s+{re.escape(table_name)}\s*:\s*List\s+AreaBandCoefficient\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*minArea\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"maxArea\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for min_area, max_area, value, section, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "minArea": float(min_area),
                "maxArea": float(max_area),
                "value": float(value),
                "citation": {
                    "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                    "sectionId": section,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": "",
                    "version": "2026-06-27",
                    "effectiveDate": "2026-06-27",
                },
            }
        )
    return rows


def _extract_usage_entries(text: str, table_name: str) -> list[dict[str, object]]:
    table_re = re.compile(rf"def\s+{re.escape(table_name)}\s*:\s*List\s+UsageFactorCoefficient\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*usage\s*:=\s*\"([^\"]+)\",\s*"
        r"value\s*:=\s*([0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for usage, value, section, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "usage": usage,
                "value": float(value),
                "citation": {
                    "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                    "sectionId": section,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": "",
                    "version": "2026-06-27",
                    "effectiveDate": "2026-06-27",
                },
            }
        )
    return rows


def _extract_indicator_method_citations(indicators_text: str) -> list[dict[str, object]]:
    pattern = re.compile(
        r"def\s+(calculate(?:Bbio|Cep|CepNr|DHFromCanicule)Citation)\s*:\s*RegulationCitation\s*:=\s*"
        r"\{\s*sourceDoc\s*:=\s*\"([^\"]+)\",\s*"
        r"sectionId\s*:=\s*\"([^\"]+)\",\s*"
        r"tableId\s*:=\s*\"([^\"]+)\",\s*"
        r"articleRef\s*:=\s*\"([^\"]+)\",\s*"
        r"equationId\s*:=\s*\"([^\"]*)\",\s*"
        r"version\s*:=\s*\"([^\"]+)\",\s*"
        r"effectiveDate\s*:=\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for symbol, source_doc, section_id, table_id, article_ref, equation_id, version, effective_date in pattern.findall(indicators_text):
        rows.append(
            {
                "symbol": symbol,
                "citation": {
                    "sourceDoc": source_doc,
                    "sectionId": section_id,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": equation_id,
                    "version": version,
                    "effectiveDate": effective_date,
                },
            }
        )
    return rows


def _extract_system_generator_entries(text: str) -> list[dict[str, object]]:
    table_re = re.compile(r"def\s+generatorConventionTable\s*:\s*List\s+GeneratorConventionEntry\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*genType\s*:=\s*\.(\w+),\s*"
        r"nominalEfficiency\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"seasonalPerformance\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"auxiliaryPower\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"primaryEnergyFactor\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkSystemCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for gen_type, nominal_eff, seasonal_perf, auxiliary_power, primary_factor, section_id, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "genType": gen_type,
                "nominalEfficiency": float(nominal_eff),
                "seasonalPerformance": float(seasonal_perf),
                "auxiliaryPower": float(auxiliary_power),
                "primaryEnergyFactor": float(primary_factor),
                "citation": {
                    "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                    "sectionId": section_id,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": "SYS-EQ-01",
                    "version": "2026-06-28",
                    "effectiveDate": "2026-06-28",
                },
            }
        )
    return rows


def _extract_system_partload_entries(text: str) -> list[dict[str, object]]:
    table_re = re.compile(r"def\s+partLoadCurveConventionTable\s*:\s*List\s+PartLoadCurveConventionEntry\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*genType\s*:=\s*\.(\w+),\s*"
        r"a0\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"a1\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"a2\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),.*?"
        r"citation\s*:=\s*mkSystemCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for gen_type, a0, a1, a2, section_id, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "genType": gen_type,
                "a0": float(a0),
                "a1": float(a1),
                "a2": float(a2),
                "citation": {
                    "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                    "sectionId": section_id,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": "SYS-EQ-01",
                    "version": "2026-06-28",
                    "effectiveDate": "2026-06-28",
                },
            }
        )
    return rows


def _extract_solar_convention_entries(text: str) -> list[dict[str, object]]:
    table_re = re.compile(r"def\s+solarConventionTable\s*:\s*List\s+SolarConventionValue\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*key\s*:=\s*\"([^\"]+)\",\s*"
        r"value\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkSolarCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for key, value, section_id, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "key": key,
                "value": float(value),
                "citation": {
                    "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                    "sectionId": section_id,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": "SOL-EQ-01",
                    "version": "2026-06-28",
                    "effectiveDate": "2026-06-28",
                },
            }
        )
    return rows


def _extract_perez_entries(text: str) -> list[dict[str, object]]:
    table_re = re.compile(r"def\s+perezSimplifiedBinTable\s*:\s*List\s+PerezSimplifiedBin\s*:=\s*\[(.*?)\]", re.S)
    m = table_re.search(text)
    if not m:
        return []
    block = m.group(1)
    row_re = re.compile(
        r"\{\s*minEpsilon\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"maxEpsilon\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"f1\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"f2\s*:=\s*([\-0-9]+(?:\.[0-9]+)?),\s*"
        r"citation\s*:=\s*mkSolarCitation\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\"([^\"]+)\"\s*\}",
        re.S,
    )
    rows = []
    for min_eps, max_eps, f1, f2, section_id, table_id, article_ref in row_re.findall(block):
        rows.append(
            {
                "minEpsilon": float(min_eps),
                "maxEpsilon": float(max_eps),
                "f1": float(f1),
                "f2": float(f2),
                "citation": {
                    "sourceDoc": "Arrete du 4 aout 2021 relatif aux exigences RE2020 + Guide RE2020",
                    "sectionId": section_id,
                    "tableId": table_id,
                    "articleRef": article_ref,
                    "equationId": "SOL-EQ-01",
                    "version": "2026-06-28",
                    "effectiveDate": "2026-06-28",
                },
            }
        )
    return rows


def build_export(
    lean_text: str,
    source_path: str,
    indicators_text: str,
    indicators_source_path: str,
    systems_text: str,
    systems_source_path: str,
    solar_text: str,
    solar_source_path: str,
    include_generated_at: bool,
) -> dict[str, object]:
    metadata: dict[str, object] = {
        "source": source_path,
        "indicatorSource": indicators_source_path,
        "systemsSource": systems_source_path,
        "solarSource": solar_source_path,
        "tableVersion": _extract_version(lean_text),
        "generator": "scripts/export_regulation_tables.py",
    }
    if include_generated_at:
        metadata["generatedAtUtc"] = datetime.now(timezone.utc).isoformat()

    return {
        "metadata": metadata,
        "tables": {
            "geoCoefficientTable": _extract_zone_entries(lean_text),
            "comblesCoefficientTable": _extract_category_entries(lean_text, "comblesCoefficientTable"),
            "bruitCoefficientTable": _extract_category_entries(lean_text, "bruitCoefficientTable"),
            "catCoefficientTable": _extract_category_entries(lean_text, "catCoefficientTable"),
            "surfMoyCoefficientTable": _extract_area_entries(lean_text, "surfMoyCoefficientTable"),
            "surfTotCoefficientTable": _extract_area_entries(lean_text, "surfTotCoefficientTable"),
            "primaryEnergyFactorTable": _extract_usage_entries(lean_text, "primaryEnergyFactorTable"),
            "nonRenewableEnergyFactorTable": _extract_usage_entries(lean_text, "nonRenewableEnergyFactorTable"),
            "indicatorMethodCitations": _extract_indicator_method_citations(indicators_text),
            "generatorConventionTable": _extract_system_generator_entries(systems_text),
            "partLoadCurveConventionTable": _extract_system_partload_entries(systems_text),
            "solarConventionTable": _extract_solar_convention_entries(solar_text),
            "perezSimplifiedBinTable": _extract_perez_entries(solar_text),
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Export RE2020 regulation tables to JSON")
    parser.add_argument(
        "--input",
        default="RE2020/RegulationTables.lean",
        help="Path to RegulationTables Lean source",
    )
    parser.add_argument(
        "--output",
        default="RE2020/data/regulation_tables_export.json",
        help="Path to write exported JSON",
    )
    parser.add_argument(
        "--indicators-input",
        default="RE2020/Indicators.lean",
        help="Path to Indicators Lean source",
    )
    parser.add_argument(
        "--systems-input",
        default="RE2020/Systems.lean",
        help="Path to Systems Lean source",
    )
    parser.add_argument(
        "--solar-input",
        default="RE2020/Solar.lean",
        help="Path to Solar Lean source",
    )
    parser.add_argument(
        "--include-generated-at",
        action="store_true",
        help="Include generatedAtUtc timestamp in metadata (disabled by default for deterministic output)",
    )
    args = parser.parse_args()

    in_path = Path(args.input)
    indicators_path = Path(args.indicators_input)
    systems_path = Path(args.systems_input)
    solar_path = Path(args.solar_input)
    out_path = Path(args.output)

    lean_text = in_path.read_text(encoding="utf-8")
    indicators_text = indicators_path.read_text(encoding="utf-8")
    systems_text = systems_path.read_text(encoding="utf-8")
    solar_text = solar_path.read_text(encoding="utf-8")
    payload = build_export(
        lean_text,
        str(in_path),
        indicators_text,
        str(indicators_path),
        systems_text,
        str(systems_path),
        solar_text,
        str(solar_path),
        args.include_generated_at,
    )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    total_rows = sum(len(v) for v in payload["tables"].values())
    print(f"Exported {total_rows} coefficient rows to {out_path}")


if __name__ == "__main__":
    main()
