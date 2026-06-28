#!/usr/bin/env python3
"""Suggest retrofit settings to reach a target indicator from a simple building file.

Supports JSON and one-row CSV input for users without CAD.
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run target-seeking retrofit suggestion")
    p.add_argument("--input", required=True, help="Path to JSON or CSV simplified building file")
    p.add_argument("--metric", required=True, choices=["bbio", "cep", "cepnr", "dh"])
    p.add_argument("--target", required=True, type=float)
    p.add_argument("--profile", choices=["conservative", "standard", "aggressive"], default="standard")
    p.add_argument("--top-k", type=int, default=1, help="Number of ranked suggestions to return")
    p.add_argument("--pareto", action="store_true", help="Use Pareto frontier pre-filtering before ranking")
    p.add_argument("--require-target", action="store_true", help="Only keep suggestions that meet target")
    p.add_argument("--cost-envelope", type=float, default=3.0)
    p.add_argument("--cost-ventilation", type=float, default=2.0)
    p.add_argument("--cost-heating", type=float, default=4.0)
    p.add_argument("--cost-window", type=float, default=1.5)
    p.add_argument("--cost-shading", type=float, default=0.5)
    p.add_argument("--max-weighted-cost", type=float, default=None, help="Discard suggestions above this weighted retrofit cost")
    p.add_argument("--json-out", default=None, help="Optional path to write structured JSON result")
    p.add_argument(
        "--strict-target",
        action="store_true",
        help="Return non-zero exit code when target is not achieved",
    )
    p.add_argument("--repo-root", default=".")
    p.add_argument("--format", choices=["auto", "json", "csv"], default="auto")
    return p.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("JSON input must be an object")
    return raw


def load_csv(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    if len(rows) != 1:
        raise ValueError("CSV input must contain exactly one data row")
    return {k: v for k, v in rows[0].items() if k is not None}


def choose_format(path: Path, requested: str) -> str:
    if requested != "auto":
        return requested
    suffix = path.suffix.lower()
    if suffix == ".json":
        return "json"
    if suffix == ".csv":
        return "csv"
    raise ValueError("Cannot auto-detect format. Use --format json or --format csv")


def require_field(data: dict[str, Any], key: str) -> str:
    value = data.get(key)
    if value is None:
        raise ValueError(f"Missing required field: {key}")
    s = str(value).strip()
    if not s:
        raise ValueError(f"Field is empty: {key}")
    return s


def optional_field(data: dict[str, Any], key: str, default: str) -> str:
    value = data.get(key)
    if value is None:
        return default
    s = str(value).strip()
    return s if s else default


def build_cli_args(data: dict[str, Any], args: argparse.Namespace) -> list[str]:
    cli_args = [
        "--name",
        require_field(data, "name"),
        "--category",
        require_field(data, "category"),
        "--zone",
        require_field(data, "climateZone"),
        "--area",
        require_field(data, "floorArea"),
        "--floors",
        optional_field(data, "floors", "1"),
        "--window-ratio",
        optional_field(data, "windowRatio", "0.18"),
        "--envelope",
        optional_field(data, "envelope", "standard"),
        "--ventilation",
        optional_field(data, "ventilation", "standardmechanical"),
        "--heating",
        optional_field(data, "heating", "airwaterheatpump"),
        "--shading",
        optional_field(data, "shading", "true"),
        "--profile",
        args.profile,
        "--top-k",
        str(max(1, args.top_k)),
        "--cost-envelope",
        str(args.cost_envelope),
        "--cost-ventilation",
        str(args.cost_ventilation),
        "--cost-heating",
        str(args.cost_heating),
        "--cost-window",
        str(args.cost_window),
        "--cost-shading",
        str(args.cost_shading),
        "--metric",
        args.metric,
        "--target",
        str(args.target),
    ]
    if args.json_out:
        cli_args.extend(["--json-out", str(Path(args.json_out).resolve())])
    if args.max_weighted_cost is not None:
        cli_args.extend(["--max-weighted-cost", str(args.max_weighted_cost)])
    if args.pareto:
        cli_args.extend(["--pareto", "true"])
    if args.require_target:
        cli_args.extend(["--require-target", "true"])
    if args.strict_target:
        cli_args.extend(["--strict-target", "true"])
    return cli_args


def main() -> None:
    args = parse_args()
    root = Path(args.repo_root).resolve()
    input_path = Path(args.input).resolve()

    if not input_path.exists():
        print(f"ERROR: input file not found: {input_path}")
        sys.exit(2)

    fmt = choose_format(input_path, args.format)
    data = load_json(input_path) if fmt == "json" else load_csv(input_path)
    cli_args = build_cli_args(data, args)

    build_cmd = ["lake", "build", "re2020_optimize"]
    run_cmd = [str(root / ".lake" / "build" / "bin" / "re2020_optimize"), *cli_args]

    build_result = subprocess.run(build_cmd, cwd=root)
    if build_result.returncode != 0:
        sys.exit(build_result.returncode)

    run_result = subprocess.run(run_cmd, cwd=root)
    # Non-strict mode should not break calling shells when target is missed.
    if run_result.returncode != 0 and not args.strict_target:
        if run_result.returncode == 2:
            sys.exit(0)
    sys.exit(run_result.returncode)


if __name__ == "__main__":
    main()
