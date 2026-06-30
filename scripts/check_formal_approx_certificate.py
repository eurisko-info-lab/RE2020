#!/usr/bin/env python3
"""Validate formal approximation certificate used by Float->Real bridge checks."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any


REQUIRED_METRICS = ("bbio", "cep", "cepNr", "dh")


def _die(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def _as_obj(raw: Any, name: str) -> dict[str, Any]:
    if not isinstance(raw, dict):
        _die(f"{name} must be an object")
    return raw


def main() -> None:
    parser = argparse.ArgumentParser(description="Check formal approximation certificate")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--certificate", default="RE2020/data/formal_approx_certificate.json")
    parser.add_argument("--max-eps", type=float, default=1e-3)
    parser.add_argument("--min-files", type=int, default=1)
    parser.add_argument("--min-samples", type=int, default=1)
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    cert_path = (root / args.certificate).resolve()
    if not cert_path.exists():
        _die(f"certificate not found: {cert_path}")

    try:
        raw = json.loads(cert_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        _die(f"invalid JSON in certificate: {exc}")

    cert = _as_obj(raw, "certificate")

    profile = cert.get("profile")
    if not isinstance(profile, str) or not profile.strip():
        _die("profile is missing")

    corpus = _as_obj(cert.get("corpus"), "corpus")
    files = corpus.get("files")
    samples = corpus.get("indicatorSamples")
    if not isinstance(files, int) or files < args.min_files:
        _die(f"corpus.files must be >= {args.min_files}")
    if not isinstance(samples, int) or samples < args.min_samples:
        _die(f"corpus.indicatorSamples must be >= {args.min_samples}")

    eps = _as_obj(cert.get("eps"), "eps")
    stats = _as_obj(cert.get("stats"), "stats")

    for metric in REQUIRED_METRICS:
        if metric not in eps:
            _die(f"eps.{metric} missing")
        if metric not in stats:
            _die(f"stats.{metric} missing")

        eps_val = eps[metric]
        if not isinstance(eps_val, (int, float)) or not math.isfinite(float(eps_val)):
            _die(f"eps.{metric} must be a finite number")
        eps_num = float(eps_val)
        if eps_num < 0.0:
            _die(f"eps.{metric} must be non-negative")
        if eps_num > args.max_eps:
            _die(f"eps.{metric}={eps_num} exceeds max-eps={args.max_eps}")

        metric_stats = _as_obj(stats[metric], f"stats.{metric}")
        max_abs = metric_stats.get("maxAbsObserved")
        cnt = metric_stats.get("samples")
        if not isinstance(max_abs, (int, float)) or not math.isfinite(float(max_abs)):
            _die(f"stats.{metric}.maxAbsObserved must be finite")
        if float(max_abs) < 0.0:
            _die(f"stats.{metric}.maxAbsObserved must be non-negative")
        if not isinstance(cnt, int) or cnt < args.min_samples:
            _die(f"stats.{metric}.samples must be >= {args.min_samples}")

    print("Formal approximation certificate guard")
    print(f"- certificate: {cert_path}")
    print(f"- profile: {profile}")
    print(f"- corpus files: {files}")
    print(f"- indicator samples: {samples}")
    print(f"- max eps allowed: {args.max_eps}")
    print("PASS: formal approximation certificate is valid")


if __name__ == "__main__":
    main()
