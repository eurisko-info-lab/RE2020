# RE2020 Gap-Closure Roadmap

## Objective
Move from current partial implementation to audit-ready RE2020 traceable implementation.

## Current baseline
- Structural coverage: about 70%
- Regulatory fidelity (certification readiness): about 35%
- Primary blockers: climate data provenance, annual simulation core, table-driven coefficients, reference validation cases

## Workstreams by criticality

### P0 (must fix first)
1. Climate dataset ingestion
- Target: replace synthetic placeholders with official climate inputs by zone, including canicule sequence.
- Files: Climate.lean
- Deliverables:
  - deterministic parser/loader
  - provenance metadata (source file id, version, checksum)
  - validation tests for array sizes and ranges
- Exit criteria: no placeholder climate values in production path.

2. Annual simulation core
- Target: implement simulateYear end-to-end with reproducible hourly outputs.
- Files: Thermal.lean
- Deliverables:
  - remove sorry
  - unit tests for energy balance and HVAC clamping logic
  - integration test for annual accumulation
- Exit criteria: simulateYear fully executable with deterministic regression fixtures.

3. Modulation tables and factor provenance
- Target: replace zero defaults with table-driven modulation and factor lookup.
- Files: RE2020.lean, Types.lean, Indicators.lean
- Deliverables:
  - encoded coefficient tables
  - mapping from building/category/zone to coefficients
  - per-value source tag in comments or metadata
- Exit criteria: no hardcoded all-zero modulation defaults.

4. Reference-case validation path
- Target: implement reference validation without placeholders.
- Files: RE2020.lean, potentially Indicators.lean/Thermal.lean
- Deliverables:
  - thermal bridge impact function wired
  - benchmark suite with pass/fail thresholds
- Exit criteria: no placeholder 0.0 in compliance-critical validation metrics.

### P1 (high-value fidelity improvements)
1. Full Cep/Cep_nr usage matrix coverage
- Extend beyond heating/cooling/lighting in final pipeline aggregation.
- Files: RE2020.lean, Indicators.lean, Systems.lean

2. Occupancy and operation conventions
- Replace heuristic schedules with table-driven scenario profiles.
- Files: Scenarios.lean

3. DH and lighting fidelity improvements
- Replace simplified thresholds and wrapper formulas with traceable equation-level methods.
- Files: Indicators.lean, Lighting.lean

### P2 (secondary but important)
1. Solar model coefficient fidelity
- Replace simplified bins/coefs with explicit referenced tables.
- Files: Solar.lean

2. Systems model hardening
- Improve part-load and auxiliary models to traceable annex equations.
- Files: Systems.lean

## Traceability requirements (Definition of Done)
Each regulatory function must include:
1. Source key: annex section + table/equation id + version date
2. Constant provenance: source table id and unit
3. Test linkage: reference-case id and expected tolerance
4. Change log entry when legal source/version changes

## Suggested execution sequence
1. P0 climate ingestion
2. P0 simulateYear completion
3. P0 modulation/factor tables
4. P0 reference validation suite
5. P1 indicator and scenario expansion
6. P2 model refinements

## Measurable targets
- Coverage target after P0: fidelity >= 60%
- Coverage target after P1: fidelity >= 80%
- Coverage target after P2: fidelity >= 90%
- Placeholder targets: sorry=0, critical placeholder=0, TODO-critical=0
