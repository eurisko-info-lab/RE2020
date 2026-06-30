# Benchmark Corpus Expansion Plan

## Objective
Expand the current official-calibrated benchmark corpus from 12 cases to 30+ cases without diluting provenance, tolerance, or reproducibility guarantees.

## Current state
- Current floor: 12 official-calibrated benchmark cases.
- Current evidence discipline:
  - source URI + checksum in code
  - official case ID
  - tolerance profile
  - local evidence artifact per case in `RE2020/data/validation/cases/`

## Constraint
This expansion cannot be completed honestly by inventing new official cases. Each added case must come from a verifiable official source with reproducible provenance.

## Target shape
- 30+ official-calibrated cases.
- Coverage targets:
  - `MaisonIndividuelle`
  - `LogementCollectif`
  - `Bureau`
  - if official material exists, extend to additional categories already exposed in the code surface
- Climate diversity targets:
  - at least 3 climate families represented
  - multiple cases per category/climate pairing where official data exists

## Admission checklist for a new benchmark case
1. Official source URL is stable and archived in the code reference.
2. Source checksum is recorded.
3. `officialCaseId` is unique.
4. `toleranceProfile` follows the calibrated official naming policy.
5. Local evidence artifact is present under `RE2020/data/validation/cases/`.
6. Legal reference catalog includes the associated citation ID.
7. Composite compliance gate remains green after insertion.

## Implementation steps
1. Acquire additional official case files and normalize naming.
2. Add corresponding `ValidationBenchmarkCase` entries in `RE2020/RE2020.lean`.
3. Add local evidence JSON files for each new `officialCaseId`.
4. Extend legal catalog coverage for the new validation citation IDs.
5. Re-run strict and deep compliance gates.
6. Regenerate buyer-facing and benchmark-report artifacts.

## Success criteria
1. Benchmark corpus count is >= 30.
2. All new cases pass provenance, tolerance, and reproducibility checks.
3. `readiness-v2` remains at 100.0 / 100.
4. External benchmark breadth becomes a competitive strength rather than a caveat.