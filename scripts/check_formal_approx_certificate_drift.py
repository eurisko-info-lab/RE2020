#!/usr/bin/env python3
"""Fail if formal approximation certificate artifacts are not committed/synchronized."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Check drift of formal approximation certificate artifacts")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--json", default="RE2020/data/formal_approx_certificate.json")
    parser.add_argument("--md", default="RE2020/data/formal_approx_certificate.md")
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    json_path = root / args.json
    md_path = root / args.md

    missing = [str(p) for p in (json_path, md_path) if not p.exists()]
    if missing:
        print("FAIL: missing certificate artifacts")
        for p in missing:
            print(f"- {p}")
        sys.exit(1)

    cmd = [
        "git",
        "diff",
        "--exit-code",
        "--",
        args.json,
        args.md,
    ]
    result = subprocess.run(cmd, cwd=root)
    print("Formal approximation certificate drift guard")
    print(f"- json: {json_path}")
    print(f"- markdown: {md_path}")

    if result.returncode != 0:
        print("FAIL: certificate artifacts are out of sync with committed files")
        print("hint: regenerate and commit updated certificate artifacts")
        sys.exit(result.returncode)

    print("PASS: certificate artifacts are committed and synchronized")


if __name__ == "__main__":
    main()
