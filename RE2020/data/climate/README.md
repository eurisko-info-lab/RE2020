# Climate Dataset Format

Deterministic file-backed climate datasets for RE2020 zones.

## Files

- One CSV per zone: `H1a.csv`, `H1b.csv`, `H1c.csv`, `H2a.csv`, `H2b.csv`, `H2c.csv`, `H2d.csv`, `H3.csv`.
- Manifest: `manifest.json`.

## CSV schema

Header:

hour,dry_bulb_temp_c,relative_humidity_pct,global_horizontal_wh_m2,direct_normal_wh_m2,diffuse_horizontal_wh_m2,wind_speed_m_s,wind_direction_deg

Rows:

- Exactly 8760 data rows (hour 0..8759)
- Decimal values with `.` separator

## Manifest schema

`manifest.json` contains:

- `datasetVersion`: dataset version identifier
- `generator`: script path
- `zoneFiles`: object keyed by zone code with:
  - `path`: relative CSV path
  - `sha256`: SHA-256 digest of file bytes
  - `rows`: expected row count (8760)

Use scripts:

- `python3 scripts/generate_climate_datasets.py`
- `python3 scripts/validate_climate_datasets.py`
