#!/usr/bin/env python3
"""Generate deterministic RE2020 climate CSV datasets and manifest.

This script mirrors the synthetic profile equations currently used in Lean,
but writes them to file-backed per-zone datasets with checksums.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path


ZONE_PARAMS = {
	"H1a": (8.5, 10.5, 45.0, 4.0),
	"H1b": (8.5, 10.5, 45.0, 4.0),
	"H1c": (8.5, 10.5, 45.0, 4.0),
	"H2a": (12.0, 9.0, 43.0, 3.0),
	"H2b": (12.0, 9.0, 43.0, 3.0),
	"H2c": (12.0, 9.0, 43.0, 3.0),
	"H2d": (12.0, 9.0, 43.0, 3.0),
	"H3": (16.0, 7.0, 41.0, 2.2),
}


def climate_row(zone: str, hour: int) -> list[float | int]:
	day = hour // 24
	hour_of_day = hour % 24
	t_mean, seasonal_amp, latitude_deg, wind_mean = ZONE_PARAMS[zone]
	day_f = float(day)
	hour_f = float(hour_of_day)
	two_pi = 2.0 * math.pi

	seasonal = seasonal_amp * math.sin(two_pi * (day_f - 81.0) / 365.0)
	diurnal = 4.0 * math.sin(two_pi * (hour_f - 8.0) / 24.0)
	dry_bulb = t_mean + seasonal + diurnal

	humidity_base = 62.0 - 0.65 * (dry_bulb - t_mean)
	relative_humidity = max(20.0, min(98.0, humidity_base))

	daylight = max(0.0, math.sin(math.pi * (hour_f - 6.0) / 12.0))
	summer_boost = max(0.15, 0.65 + 0.35 * math.sin(two_pi * (day_f - 81.0) / 365.0))
	global_horizontal = 900.0 * daylight * summer_boost
	direct_normal = global_horizontal * 0.72
	diffuse_horizontal = global_horizontal * 0.28

	wind_speed = max(0.2, wind_mean + 1.1 * math.sin(two_pi * hour_f / 24.0))
	wind_direction = 180.0 + 30.0 * math.sin(two_pi * day_f / 7.0) + latitude_deg / 10.0

	return [
		hour,
		dry_bulb,
		relative_humidity,
		global_horizontal,
		direct_normal,
		diffuse_horizontal,
		wind_speed,
		wind_direction,
	]


def sha256_file(path: Path) -> str:
	h = hashlib.sha256()
	with path.open("rb") as f:
		for chunk in iter(lambda: f.read(65536), b""):
			h.update(chunk)
	return h.hexdigest()


def generate_zone_csv(out_dir: Path, zone: str) -> tuple[str, int]:
	path = out_dir / f"{zone}.csv"
	with path.open("w", encoding="utf-8", newline="") as f:
		writer = csv.writer(f)
		writer.writerow(
			[
				"hour",
				"dry_bulb_temp_milli_c",
				"relative_humidity_milli_pct",
				"global_horizontal_milli_wh_m2",
				"direct_normal_milli_wh_m2",
				"diffuse_horizontal_milli_wh_m2",
				"wind_speed_milli_m_s",
				"wind_direction_milli_deg",
			]
		)
		for hour in range(8760):
			row = climate_row(zone, hour)
			writer.writerow(
				[
					row[0],
					int(round(float(row[1]) * 1000.0)),
					int(round(float(row[2]) * 1000.0)),
					int(round(float(row[3]) * 1000.0)),
					int(round(float(row[4]) * 1000.0)),
					int(round(float(row[5]) * 1000.0)),
					int(round(float(row[6]) * 1000.0)),
					int(round(float(row[7]) * 1000.0)),
				]
			)
	return str(path), 8760


def main() -> None:
	parser = argparse.ArgumentParser(description="Generate deterministic climate datasets")
	parser.add_argument(
		"--output-dir",
		default="RE2020/data/climate",
		help="Output directory for zone CSV files and manifest",
	)
	parser.add_argument(
		"--dataset-version",
		default="meteo-fr-profile-v0",
		help="Dataset version string written to manifest",
	)
	args = parser.parse_args()

	out_dir = Path(args.output_dir)
	out_dir.mkdir(parents=True, exist_ok=True)

	zone_files: dict[str, dict[str, object]] = {}
	for zone in sorted(ZONE_PARAMS):
		generated_path, rows = generate_zone_csv(out_dir, zone)
		rel_path = str(Path(generated_path).relative_to(out_dir))
		digest = sha256_file(Path(generated_path))
		zone_files[zone] = {
			"path": rel_path,
			"sha256": digest,
			"rows": rows,
		}

	manifest = {
		"datasetVersion": args.dataset_version,
		"generator": "scripts/generate_climate_datasets.py",
		"zoneFiles": zone_files,
	}
	manifest_path = out_dir / "manifest.json"
	manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

	print(f"Generated {len(zone_files)} zone files in {out_dir}")
	print(f"Wrote manifest: {manifest_path}")


if __name__ == "__main__":
	main()
