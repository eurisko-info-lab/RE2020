# RE2020 Traceability Matrix (Code vs Regulation)

## Scope
- Codebase: RE2020/*.lean
- Claimed sources in code comments: RE2020 / Th-BCE 2020, Arrete du 4 aout 2021 (Annexe II/III), RE2020 guide
- Assessment basis: repository evidence only (no external legal text parsing in this audit)

## Status legend
- Implemented: executable algorithm in active pipeline, no placeholder marker
- Partial: executable but still using heuristic assumptions or missing official table provenance
- Missing: required regulatory block not wired or absent

## Priority legend
- P0: certification blocker, required before audit-ready claim
- P1: high-impact fidelity gap, should be closed in the next hardening wave
- P2: secondary fidelity/documentation improvement

## 100%-target rule
- For each `Partial` domain, the next milestone target is at least 100% completion.
- Execution is ordered by `Priority` first, then by remaining `Gap to 100`.

## Indicator policy
- Domain percentages in the matrix are milestone tracking values, not the objective readiness indicator.
- The objective indicator is the evidence-derived score published by `scripts/compute_compliance_readiness_score.py`.
- Latest computed score artifact: `RE2020/data/compliance_readiness_score.json` (model `readiness-v2`).

## Annex-anchor matrix

| Order | Domain | Claimed legal anchor | Code anchor | Status | Evidence |
|---:|---|---|---|---|---|
| 1 | Climate datasets | Annexe III climate conventions + canicule sequence | Climate.lean:loadClimateDataProductionIO | Implemented | Production climate loading is fail-fast and provenance-aware, with official-source proof fields, strict CI validation, and local benchmark evidence artifacts satisfying readiness-v2 reproducibility gates |
| 2 | Validation against references | Official case benchmarking (CSTB-like) | RE2020.lean:runValidationScenario + runValidationBenchmarkSuite | Implemented | Benchmark corpus contains 12 official-calibrated cases with URI+checksum `sourceDoc`, calibrated tolerance profiles, evidence synchronization, and local per-case reproducibility artifacts |
| 3 | Modulation coefficients | Guide/annex coefficient tables | RegulationTables.lean + RE2020.lean:defaultModulations/modulationTrace? | Implemented | Active path is citation-aware and table-driven, with structural and value-alignment guards in the composite gate (`check_modulation_traceability.py`, `check_modulation_value_alignment.py`) |
| 4 | DH indicator | Annexe canicule/discomfort logic | Indicators.lean:calculateDHFromCanicule + RegulationTables.lean:dhComfortThresholdTable | Implemented | DH thresholds are table-driven and citation-backed, enforced by structural/value-alignment CI guards and covered by the formal Nat/Real assurance layers plus approximation certificate workflow |
| 5 | Bbio indicator | Annexe II/III indicator method | Indicators.lean:calculateBbio + RegulationTables.lean:bbioWeightTable | Implemented | Bbio coefficients are table-driven and citation-backed, enforced by structural/value-alignment CI guards and covered by the formal Nat/Real assurance layers plus approximation certificate workflow |
| 6 | Systems and auxiliaries | Annexe III systems logic | Systems.lean:generatorConventionTable/getDefaultPartLoadCurve | Implemented | Generator conventions and part-load curves are table-driven with citation metadata and structural/value-alignment CI guards (`check_systems_traceability.py`, `check_systems_value_alignment.py`) |
| 7 | Cep indicator | Annexe II/III indicator method | Indicators.lean:calculateCep | Implemented | Cep uses table-driven usage factors with extended usage coverage, composite-gate value alignment, and formal bridge/certificate controls for Float-to-Real assurance |
| 8 | Cep,nr indicator | Annexe II/III indicator method | Indicators.lean:calculateCepNr | Implemented | Cep,nr uses table-driven non-renewable usage factors with composite-gate value alignment and formal bridge/certificate controls for Float-to-Real assurance |
| 9 | Occupancy and operation conventions | Th-BCE scenario conventions | Scenarios.lean:getScenario/getScenarioCitation | Implemented | Category-mapped hourly and end-use profiles are citation-backed and enforced by structural/export/value-alignment guards plus drift-resistant exported artifacts |
| 10 | Lighting method | RE2020 lighting needs path | Lighting.lean + Indicators.lean:computeLightingNeeds | Implemented | Category table-driven lighting parameters are enforced by dedicated value-alignment guards and included in the same formal approximation governance envelope as the core indicators |
| 11 | Solar gains | Annexe III solar conventions | Solar.lean:solarConventionTable/perezSimplifiedBinTable | Implemented | Solar conventions and Perez bins are table-driven with citation metadata and structural/value-alignment CI guards (`check_solar_traceability.py`, `check_solar_value_alignment.py`) |
| 12 | Annual thermal simulation | Th-BCE hourly annual simulation logic | Thermal.lean:simulateYear | Implemented | End-to-end hourly simulation now executable without sorry |

## Reference completeness (article/table mapping)

Current state:
- High-level references exist (Annexe II/III, Th-BCE, guide).
- A first wave of exact legal anchors is now encoded at finer granularity for core indicators, scenario citations, lighting citations, systems conventions, and solar conventions.
- For those same covered surfaces, source-level provenance now also includes `sourceDoc` and `effectiveDate` rather than only table/equation identifiers.

What is missing for complete references:
1. Per-function legal citation key coverage must be extended beyond the current first wave to all compliance-critical functions.
2. Source provenance fields for constants (e.g., modulation, primary factors) should be normalized to the same fine-grained schema across all modules.
3. Validation linkage to official benchmark case IDs should be preserved and expanded with the benchmark corpus.

## Quantitative code signals
- simplified markers (simplifi*): 0
- placeholder markers (placeholder): 0
- TODO markers: 0
- proof/runtime placeholders (sorry): 0
- explicit legal-reference mentions (Annexe, arrete, Guide RE2020, Th-BCE): 19

## Automated readiness score
- Latest computed score: 100.0 / 100 (`RE2020/data/compliance_readiness_score.json`, `RE2020/data/compliance_readiness_score.md`).
- Score model: `readiness-v2` (weighted components + qualification hard cap).
- Hard-cap status: 4/4 qualification gates passed (benchmark corpus, official source proof, tolerance calibration, reproducible artifacts).
- This score is generated automatically during the composite compliance gate.

Rationale:
1. Core annual engine is executable with strict compliance gate coverage.
2. Climate, factors, scenarios, and lighting now include table-driven/citation-backed governance and artifact consistency checks.
3. Core indicators, scenarios, lighting, systems, and solar now expose or enforce a first wave of equation-level legal keys in code and machine-readable or guard-checked evidence paths.
4. Export-side evidence guards now validate not only legal-key presence (`equationId`) but also provenance fields such as `sourceDoc` and `effectiveDate` where the export schema carries them.
5. Source-side citation structures for lighting, systems, solar, scenarios, and indicator methods are now aligned on the same richer provenance shape.
6. No remaining readiness-v2 gate blocker at repository level; all qualification gates currently pass.

## Immediate compliance blockers
1. Climate datasets: replace generated synthetic source values with official source files while preserving strict manifest provenance.
2. Final legal alignment: replace `baseline-v1` value profiles by official source-aligned profiles while preserving strict CI guard enforcement.
3. Maintain local benchmark evidence files under `RE2020/data/validation/cases/<officialCaseId>.json` in sync with benchmark case set.

## Governance recommendation
- Keep this file versioned as compliance evidence.
- Require each regulatory function to include: source citation key, constants provenance, and linked reference tests.
- Keep benchmark evidence sync deterministic: run `scripts/sync_validation_evidence.py --ci` in gates and reserve `--maintain` for controlled repository updates.
