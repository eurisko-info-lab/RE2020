#!/usr/bin/env python3
"""Validate generated RE2020 climate datasets and manifest integrity."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path


EXPECTED_HEADER = [
    "hour",
    "dry_bulb_temp_milli_c",
    "relative_humidity_milli_pct",
    "global_horizontal_milli_wh_m2",
    "direct_normal_milli_wh_m2",
    "diffuse_horizontal_milli_wh_m2",
    "wind_speed_milli_m_s",
    "wind_direction_milli_deg",
]

REQUIRED_ZONES = {"H1a", "H1b", "H1c", "H2a", "H2b", "H2c", "H2d", "H3"}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def validate_zone_file(base_dir: Path, zone: str, spec: dict[str, object]) -> list[str]:
    errors: list[str] = []

    rel_path = spec.get("path")
    expected_sha = spec.get("sha256")
    expected_rows = spec.get("rows")

    if not isinstance(rel_path, str):
        return [f"zone {zone}: missing or invalid 'path'"]
    if not isinstance(expected_sha, str):
        return [f"zone {zone}: missing or invalid 'sha256'"]
    if not isinstance(expected_rows, int):
        return [f"zone {zone}: missing or invalid 'rows'"]

    path = base_dir / rel_path
    if not path.exists():
        return [f"zone {zone}: missing file {path}"]

    actual_sha = sha256_file(path)
    if actual_sha != expected_sha:
        errors.append(f"zone {zone}: sha256 mismatch (expected {expected_sha}, got {actual_sha})")

    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        try:
            header = next(reader)
        except StopIteration:
            return [f"zone {zone}: empty file"]

        if header != EXPECTED_HEADER:
            errors.append(f"zone {zone}: invalid header")

        row_count = 0
        for row_count, row in enumerate(reader, start=1):
            if len(row) != 8:
                errors.append(f"zone {zone}: row {row_count} has {len(row)} columns")
                continue
            try:
                hour = int(row[0])
                dry_milli = int(row[1])
                rh_milli = int(row[2])
                ghi_milli = int(row[3])
                dni_milli = int(row[4])
                dhi_milli = int(row[5])
                wind_milli = int(row[6])
                wind_dir_milli = int(row[7])
            except ValueError:
                errors.append(f"zone {zone}: row {row_count} contains non-numeric value")
                continue

            dry = dry_milli / 1000.0
            rh = rh_milli / 1000.0
            ghi = ghi_milli / 1000.0
            dni = dni_milli / 1000.0
            dhi = dhi_milli / 1000.0
            wind = wind_milli / 1000.0
            wind_dir = wind_dir_milli / 1000.0

            if hour != row_count - 1:
                errors.append(f"zone {zone}: row {row_count} hour index mismatch (got {hour})")
            if not (0.0 <= rh <= 100.0):
                errors.append(f"zone {zone}: row {row_count} humidity out of range")
            if ghi < 0.0 or dni < 0.0 or dhi < 0.0:
                errors.append(f"zone {zone}: row {row_count} radiation must be >= 0")
            if wind < 0.0:
                errors.append(f"zone {zone}: row {row_count} wind speed must be >= 0")
            if not (0.0 <= wind_dir <= 360.0):
                errors.append(f"zone {zone}: row {row_count} wind direction out of range")
            if dry < -60.0 or dry > 60.0:
                errors.append(f"zone {zone}: row {row_count} dry bulb outside sanity bounds")

        if row_count != expected_rows:
            errors.append(f"zone {zone}: row count mismatch (expected {expected_rows}, got {row_count})")

    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate deterministic climate datasets")
    parser.add_argument(
        "--input-dir",
        default="RE2020/data/climate",
        help="Directory containing manifest.json and zone CSV files",
    )
    args = parser.parse_args()

    base_dir = Path(args.input_dir)
    manifest_path = base_dir / "manifest.json"
    if not manifest_path.exists():
        print(f"ERROR: manifest not found: {manifest_path}")
        sys.exit(2)

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {manifest_path}: {exc}")
        sys.exit(2)

    zone_files = manifest.get("zoneFiles")
    if not isinstance(zone_files, dict):
        print("ERROR: manifest has no valid 'zoneFiles' object")
        sys.exit(2)

    declared_zones = set(zone_files.keys())
    missing_zones = sorted(REQUIRED_ZONES - declared_zones)
    unexpected_zones = sorted(declared_zones - REQUIRED_ZONES)

    all_errors: list[str] = []
    for zone in missing_zones:
        all_errors.append(f"manifest: missing required zone {zone}")
    for zone in unexpected_zones:
        all_errors.append(f"manifest: unexpected zone {zone}")

    for zone, spec in sorted(zone_files.items()):
        if not isinstance(spec, dict):
            all_errors.append(f"zone {zone}: spec is not an object")
            continue
        all_errors.extend(validate_zone_file(base_dir, zone, spec))

    print("Climate dataset validation")
    print(f"- manifest: {manifest_path}")
    print(f"- zones: {len(zone_files)}")

    if all_errors:
        print(f"\nFAIL: {len(all_errors)} issue(s) found")
        for err in all_errors:
            print(f"- {err}")
        sys.exit(1)

    print("\nPASS: all climate datasets are valid")


if __name__ == "__main__":
    main()
