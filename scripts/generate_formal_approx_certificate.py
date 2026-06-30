#!/usr/bin/env python3
"""Generate an empirical approximation certificate for formal Float->Real margins.

The certificate is corpus-derived from example result artifacts and provides
conservative per-metric eps values (absolute margins).
"""

from __future__ import annotations

import argparse
import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


METRICS = ("bbio", "cep", "cepNr", "dh")


def _normalize_metric_keys(d: dict[str, Any]) -> dict[str, float] | None:
    if "bbio" not in d or "cep" not in d or "dh" not in d:
        return None
    cep_nr_val = d.get("cepNr", d.get("cepnr"))
    if cep_nr_val is None:
        return None
    values = {
        "bbio": d.get("bbio"),
        "cep": d.get("cep"),
        "cepNr": cep_nr_val,
        "dh": d.get("dh"),
    }
    normalized: dict[str, float] = {}
    for k, v in values.items():
        if isinstance(v, (int, float)) and math.isfinite(float(v)):
            normalized[k] = float(v)
        else:
            return None
    return normalized


def _walk_collect(obj: Any, out: list[dict[str, float]]) -> None:
    if isinstance(obj, dict):
        normalized = _normalize_metric_keys(obj)
        if normalized is not None:
            out.append(normalized)
        for v in obj.values():
            _walk_collect(v, out)
    elif isinstance(obj, list):
        for item in obj:
            _walk_collect(item, out)


def _load_indicator_sets(paths: list[Path]) -> list[dict[str, float]]:
    all_sets: list[dict[str, float]] = []
    for path in paths:
        raw = json.loads(path.read_text(encoding="utf-8"))
        _walk_collect(raw, all_sets)
    return all_sets


def _build_md_report(cert: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append("# Formal Approximation Certificate")
    lines.append("")
    lines.append(f"- profile: `{cert['profile']}`")
    lines.append(f"- generatedAt: `{cert['generatedAt']}`")
    lines.append(f"- corpus files: `{cert['corpus']['files']}`")
    lines.append(f"- indicator samples: `{cert['corpus']['indicatorSamples']}`")
    lines.append("")
    lines.append("## Epsilons")
    lines.append("")
    lines.append("| metric | epsilon | maxAbsObserved | samples |")
    lines.append("|---|---:|---:|---:|")
    for metric in METRICS:
        stat = cert["stats"][metric]
        lines.append(
            f"| {metric} | {cert['eps'][metric]:.12g} | {stat['maxAbsObserved']:.12g} | {stat['samples']} |"
        )
    lines.append("")
    lines.append("## Model")
    lines.append("")
    lines.append("```")
    lines.append("eps(metric) = max(absFloor, maxAbsObserved(metric) * relativeFactor)")
    lines.append("```")
    lines.append("")
    lines.append(f"- relativeFactor: `{cert['model']['relativeFactor']}`")
    lines.append(f"- absFloor: `{cert['model']['absFloor']}`")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate formal approximation certificate")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--examples-dir", default="examples")
    parser.add_argument("--glob", default="result_*.json")
    parser.add_argument("--relative-factor", type=float, default=1e-10)
    parser.add_argument("--abs-floor", type=float, default=1e-9)
    parser.add_argument("--json-out", default="RE2020/data/formal_approx_certificate.json")
    parser.add_argument("--md-out", default="RE2020/data/formal_approx_certificate.md")
    args = parser.parse_args()

    if args.relative_factor <= 0.0 or args.abs_floor <= 0.0:
        raise SystemExit("relative-factor and abs-floor must be strictly positive")

    root = Path(args.repo_root).resolve()
    examples_dir = (root / args.examples_dir).resolve()
    paths = sorted(p for p in examples_dir.glob(args.glob) if p.is_file())
    if not paths:
        raise SystemExit(f"No example files matched {args.glob} in {examples_dir}")

    indicator_sets = _load_indicator_sets(paths)
    if not indicator_sets:
        raise SystemExit("No indicator sets were found in the selected corpus")

    stats: dict[str, dict[str, float | int]] = {
        m: {"maxAbsObserved": 0.0, "samples": 0} for m in METRICS
    }
    for item in indicator_sets:
        for m in METRICS:
            val = abs(item[m])
            stats[m]["samples"] = int(stats[m]["samples"]) + 1
            if val > float(stats[m]["maxAbsObserved"]):
                stats[m]["maxAbsObserved"] = val

    eps = {
        m: max(args.abs_floor, float(stats[m]["maxAbsObserved"]) * args.relative_factor)
        for m in METRICS
    }

    cert: dict[str, Any] = {
        "profile": "empirical-float-real-bridge-v1",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "model": {
            "relativeFactor": args.relative_factor,
            "absFloor": args.abs_floor,
            "rationale": "Conservative magnitude-scaled absolute margin derived from observed corpus extrema.",
        },
        "corpus": {
            "examplesDir": str(examples_dir.relative_to(root)),
            "glob": args.glob,
            "files": len(paths),
            "indicatorSamples": len(indicator_sets),
        },
        "files": [str(p.relative_to(root)) for p in paths],
        "stats": stats,
        "eps": eps,
    }

    json_out = (root / args.json_out).resolve()
    md_out = (root / args.md_out).resolve()
    json_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.parent.mkdir(parents=True, exist_ok=True)

    json_out.write_text(json.dumps(cert, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md_out.write_text(_build_md_report(cert), encoding="utf-8")

    print("Formal approximation certificate generated")
    print(f"- profile: {cert['profile']}")
    print(f"- corpus files: {cert['corpus']['files']}")
    print(f"- indicator samples: {cert['corpus']['indicatorSamples']}")
    print(f"- json: {json_out}")
    print(f"- markdown: {md_out}")


if __name__ == "__main__":
    main()
