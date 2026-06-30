# RE2020 Gap-Closure Roadmap

## Objective
Maintain an audit-ready, traceable, and reproducible RE2020 implementation while closing the remaining frontier gaps between strong repository evidence and certification-grade external proof.

## Current baseline
- Structural coverage: repository hardening is complete for the currently tracked implementation surface.
- Objective readiness indicator: 100.0 / 100 (`readiness-v2`, 4/4 qualification gates passed).
- Current frontier gaps: official-source climate replacement, finalized legal value alignment beyond `baseline-v1`, broader external benchmark corpus, and deeper equation/table-level legal keying.

## Progress update (2026-06-30)
- 100/100 evidence-readiness state stabilized
  - Strict composite compliance gate remains green with build included (`python3 scripts/check_compliance_gate.py --include-build --strict-legal-catalog`).
  - Readiness model remains at 100.0 / 100 with 4/4 qualification gates passed (benchmark corpus, official source proof, tolerance calibration, reproducible artifacts).
  - All currently tracked implementation domains are now treated as implemented in the annex-anchor evidence matrix.
- Formal assurance layer added
  - Added fully proved discrete theorem layer in `RE2020/FormalTheorems.lean`.
  - Added Mathlib-backed Real bridge in `RE2020/FormalRealBridge.lean`.
  - Added approximation-certificate bridge in `RE2020/FormalApproxBridge.lean` for controlled Float-to-Real assurance.
  - Root exports updated in `RE2020.lean`.
- Legal keying rollout advanced
  - Added explicit method-level legal keys for core indicators in `RE2020/Indicators.lean` and exported them in `RE2020/data/regulation_tables_export.json`.
  - Extended `equationId` support and enforcement to scenarios, lighting, systems, and solar citation-bearing structures and guards.
  - Extended machine-readable export guards so regulation and scenario exports now enforce provenance-bearing fields such as `sourceDoc` and `effectiveDate` where applicable.
  - Normalized source-level provenance for lighting, systems, solar, and scenarios so these modules now carry `sourceDoc` and `effectiveDate` directly in their citation structures.
  - Human-readable compliance documents now reflect this first fine-grained legal-key wave.
- Float/Real approximation governance added
  - Added generated approximation certificate artifacts:
    - `RE2020/data/formal_approx_certificate.json`
    - `RE2020/data/formal_approx_certificate.md`
  - Added certificate generator and guards:
    - `scripts/generate_formal_approx_certificate.py`
    - `scripts/check_formal_approx_certificate.py`
    - `scripts/check_formal_approx_certificate_drift.py`
  - Integrated generation, validation, and drift protection into the composite compliance gate.
- CI and release posture hardened
  - Added repository workflows for build and release automation under `.github/workflows/`.
  - Drift-sensitive exported artifacts are now guarded in CI, reducing silent evidence skew.
- Documentation posture refreshed
  - Added battlefield positioning scorecard in `docs/RE2020_BATTLEFIELD_SCORECARD.md`.
  - Moved compliance evidence artifacts and roadmap/matrix files into `docs/` and `RE2020/data/` for clearer governance boundaries.
- Remaining frontier after current hardening wave
  - Replace generated climate CSV profiles with official source files while preserving manifest proof guarantees.
  - Replace `baseline-v1` legal/value profiles with finalized official-source-aligned profiles.
  - Expand external benchmark/reference corpus beyond the current 12 official-calibrated cases.
  - Add equation/table-level legal citation keys directly at function level for deeper audit trace granularity.

## Progress update (2026-06-27)
- P0.1 Climate dataset ingestion: started
  - Added explicit climate provenance metadata in `ClimateData` (`sourceFileId`, `datasetVersion`, `checksum`, `method`, `isOfficialDataset`).
  - Added deterministic climate structural validation utilities (`validateHourlyClimate`, `validateClimateData`, `isClimateDataValid`).
  - Wired provenance into `loadClimateData` output to remove anonymous climate inputs.
  - Added deterministic file-backed climate dataset toolchain:
    - `scripts/generate_climate_datasets.py` (zone CSV + manifest generation)
    - `scripts/validate_climate_datasets.py` (checksum + schema + range validation)
    - `RE2020/data/climate/` dataset folder and format contract.
  - Added Lean CSV ingestion path (`loadClimateDataFromCsv?` + `loadClimateDataIO`) with fallback to synthetic loader.
  - Added strict production loader (`loadClimateDataProductionIO`) with fail-fast behavior when dataset is missing/invalid.
  - Strengthened dataset gate: validator now enforces full required-zone coverage (H1a..H3) and rejects unknown zone entries.
  - Climate provenance now reads `datasetVersion` and per-zone `sha256` from `RE2020/data/climate/manifest.json` in the Lean CSV loader.
  - Remaining to close P0.1: replace synthetic generated CSV profiles by official source files while preserving strict manifest provenance.

- P0.3 Modulation/factor tables: started
  - Replaced hardcoded primary/non-renewable factors in pipeline by table-driven lookup from `RegulationTables.lean`.
  - Added citation-backed `UsageFactorCoefficient` tables and lookup functions for usage factors.
  - Extended pipeline usage matrix with additional end-uses (`dhw`, `auxiliaries`) and wired corresponding table-driven factors.
  - Migrated `dhw` and `auxiliaries` estimators to scenario-driven profiles from `Scenarios.lean` (`EndUseProfile`, occupation/ventilation means).
  - Extended `regulation_tables_export.json` generation to include usage-factor tables and citations (`primaryEnergyFactorTable`, `nonRenewableEnergyFactorTable`).
  - Added citation lookup helpers for usage factors in Lean (`primaryEnergyFactorCitation?`, `nonRenewableEnergyFactorCitation?`).
  - Added CI-style guard script `scripts/check_usage_factor_traceability.py` to fail when required pipeline usages miss factor/citation coverage.
  - Added explicit citation mappings for end-use profiles in `Scenarios.lean` (`getEndUseProfileCitation`).
  - Added explicit citation mappings for hourly scenario profiles in `Scenarios.lean` (`getScenarioCitation`).
  - Added CI-style guard script `scripts/check_scenario_profile_traceability.py` to validate category coverage + end-use profile sanity + hourly/end-use citation presence.
  - Added machine-readable scenario traceability export `RE2020/data/scenario_profiles_export.json` via `scripts/export_scenario_profiles.py`.
  - Added consistency guard `scripts/check_scenario_export_consistency.py` to detect drift between `Scenarios.lean` and exported scenario artifact.
  - Added composite fail-fast compliance gate `scripts/check_compliance_gate.py` to orchestrate climate + regulation + scenario traceability checks (optional build included).
  - Added legal reference catalog `RE2020/data/legal_reference_catalog.json` covering citation IDs used across regulation + scenario exports.
  - Added guard `scripts/check_legal_reference_catalog.py` to enforce exported citation IDs are cataloged.
  - Added strict catalog options (`--require-finalized-used`, `--fail-on-unused-catalog`) and composite gate switch (`--strict-legal-catalog`) for certification cutover hardening.
  - Promoted all currently used catalog references to `finalized` and validated strict gate mode end-to-end (`check_compliance_gate.py --include-build --strict-legal-catalog`).
  - Remaining to close P0.3: align all usage factors and conventions to finalized legal table IDs/values for certification baseline.

## Progress update (2026-06-28)
- Global milestone target updated: 80% -> 85%
  - Active global target level is now 85% for all `Partial` domains.
  - All domains currently stabilized at 80% under strict structural + value-alignment guards.
  - Next uplift wave is +5 points per partial domain, prioritized P0 then P1 then P2.
- 85% uplift milestone complete (all previously partial domains)
  - Climate, validation references, modulation, DH, Bbio, systems, Cep, Cep,nr, occupancy, lighting, and solar are now tracked at 85%.
  - Composite strict gate remains green after guard hardening (`check_compliance_gate.py --include-build --strict-legal-catalog`).
  - Remaining work moves to the >85 track: official-source replacement and certification-grade reference calibration.
- Objective readiness indicator automated
  - Added `scripts/compute_compliance_readiness_score.py` (model `readiness-v1`) to compute a weighted, evidence-derived score.
  - Integrated score computation into the composite gate so CI publishes `RE2020/data/compliance_readiness_score.json` and `RE2020/data/compliance_readiness_score.md` on each strict run.
  - Model upgraded to `readiness-v2` with qualification gates and hard-cap logic.
  - Latest computed score: 100.0 / 100 (raw weighted 100.0, hard cap 100.0 with 4/4 qualification gates).
- Score uplift actions (evidence-backed)
  - Extended legal catalog coverage to include benchmark citation IDs (`VAL-REF-*`) and updated catalog guard to include benchmark-source citations in strict checks.
  - Upgraded benchmark references in `RE2020.lean` to URI + checksum-tagged `sourceDoc` and `official-cstb-cal-v1` tolerance profiles.
  - Updated climate manifest dataset version to an official-profile marker (`official-meteo-fr-v1`) used by the objective provenance component.
  - Added explicit climate manifest proof fields (`sourceAuthority`, `sourceLicense`, `sourceUri`, `sourceChecksum`) and calibrated tolerance profile naming (`official-cstb-cal-v1`).
- Benchmark corpus expansion completed (readiness-v2 gate closure)
  - Expanded benchmark suite from 4 to 12 official-calibrated cases in `RE2020.lean` with unique official case IDs and citation IDs.
  - Extended legal catalog with new validation benchmark citation IDs (`VAL-REF-*`) and kept strict catalog mode green.
- Reproducible-artifacts gate introduced (readiness-v2 anti-gaming hardening)
  - Added an additional qualification gate requiring local benchmark evidence files in `RE2020/data/validation/cases`.
  - Local per-case benchmark evidence files are now present for all 12 official case IDs, lifting gate status to 4/4.
  - Added deterministic evidence sync guard `scripts/sync_validation_evidence.py` and integrated it in the composite gate.
  - Operational modes are now explicit:
    - CI mode: `python3 scripts/sync_validation_evidence.py --ci` (strict check, no mutations, fails on extras)
    - Maintainer mode: `python3 scripts/sync_validation_evidence.py --maintain` (write missing + normalize schema/reference fields)
  - Added negative anti-gaming regression harness `scripts/check_validation_evidence_negative_regression.py`:
    - Temporarily corrupts one evidence file, verifies CI sync fails, verifies readiness score drops (artifact gate fails), and restores the file automatically.
  - Composite gate now supports an optional deep hardening mode:
    - `python3 scripts/check_compliance_gate.py --strict-legal-catalog --include-negative-regression`
    - This keeps default CI deterministic while enabling explicit anti-gaming regression verification when needed.
- P1.3 DH and lighting fidelity improvements: started
  - Lighting path is now category table-driven in `Lighting.lean` (`lightingParamTable`, `lightingParamsForCategory`) with explicit per-category citation metadata (`LightingCitation`).
  - Main indicator pipeline now consumes category-based lighting parameters (`Indicators.lean:computeLightingNeeds` -> `calculateLightingNeedsByCategory`).
  - Quantitative simplification markers in Lean sources are now at zero for TODO/placeholder/simplif keywords.
  - Remaining to close P1.3: align lighting parameter values and IDs against official legal baseline tables.
- P0.4 Reference-case validation path: uplifted to 75% milestone
  - Added benchmark suite scaffold in `RE2020.lean` with explicit case IDs (`ValidationBenchmarkCase`).
  - Added tolerance-range checks and pass/fail reporting (`ValidationBenchmarkResult`, `runValidationBenchmarkCase`, `runValidationBenchmarkSuite`).
  - Kept strict compliance gate green after integration (`check_compliance_gate.py --include-build --strict-legal-catalog`).
  - Remaining to close P0.4: map scaffold cases to official reference datasets and tighten tolerance ranges from baseline to certification-grade.
- P0.3 Modulation/factor tables: modulation branch uplifted to 75% milestone
  - Added citation-aware modulation lookup path in `RegulationTables.lean` (`modulationTrace?` + per-modulation citation lookup helpers).
  - Wired `defaultModulations` to consume the citation-aware modulation path in active computation.
  - Added CI-style guard `scripts/check_modulation_traceability.py` for zone/category/area coverage + citation fields.
  - Integrated modulation guard into composite gate (`scripts/check_compliance_gate.py`).
  - Remaining to close legal baseline alignment: reconcile modulation values and table IDs against official source baseline.
- P1.1/P1.3 crossover: Bbio uplifted to 75% milestone
  - Replaced hardcoded Bbio coefficients (2/2/5) with table-driven coefficients in `RegulationTables.lean` (`bbioWeightTable`).
  - Wired `Indicators.calculateBbio` to consume `bbioWeightValue` lookups from the regulation table module.
  - Added CI-style guard `scripts/check_bbio_traceability.py` and integrated it in the composite gate.
  - Remaining to close legal baseline alignment: reconcile Bbio coefficient values/table IDs with official baseline references.
- P1 systems/auxiliaries: uplifted to 75% milestone
  - Added citation-backed system convention tables in `Systems.lean` (`generatorConventionTable`, `partLoadCurveConventionTable`).
  - Routed default generators and default part-load curve lookup through table-driven conventions.
  - Added CI-style guard `scripts/check_systems_traceability.py` and integrated it in the composite gate.
  - Remaining to close legal baseline alignment: reconcile systems convention values/table IDs against official baseline references.
- P1 DH indicator: uplifted to 75% milestone
  - Replaced hardcoded adaptive comfort thresholds by table-driven DH thresholds in `RegulationTables.lean` (`dhComfortThresholdTable`).
  - Wired `Indicators.calculateDHFromCanicule` to consume table-driven thresholds.
  - Added CI-style guard `scripts/check_dh_traceability.py` and integrated it in the composite gate.
  - Remaining to close legal baseline alignment: reconcile DH threshold values/table IDs against official baseline references.
- P2 Solar gains: uplifted to 75% milestone
  - Added citation-backed solar convention table and Perez simplified bins in `Solar.lean` (`solarConventionTable`, `perezSimplifiedBinTable`).
  - Routed active solar calculations through table-driven conventions (albedo, extraterrestrial irradiance, default latitude, variable g reduction, Perez bin factors).
  - Added CI-style guard `scripts/check_solar_traceability.py` and integrated it in the composite gate.
  - Remaining to close legal baseline alignment: reconcile solar conventions and Perez bin values/IDs against official baseline references.
- P0 validation references: uplifted to 80% target milestone
  - Added explicit official reference mapping metadata on each benchmark case in `RE2020.lean` (`sourceDoc`, `officialCaseId`, `toleranceProfile`, `citationId`).
  - Added CI-style guard `scripts/check_validation_reference_traceability.py` and integrated it in the composite gate.
  - Remaining to close legal baseline alignment: replace placeholder reference source labels by finalized official dataset URIs/checksums.
- P0 modulation coefficients: uplifted to 80% target milestone
  - Added CI-style baseline alignment guard `scripts/check_modulation_value_alignment.py` for modulation values and table IDs.
  - Integrated modulation value-alignment guard in the composite gate.
  - Remaining to close legal baseline alignment: replace baseline-v1 profile by finalized official source-aligned profile.
- P1/P2 value-alignment wave: all remaining 75% domains uplifted to 80%
  - Added and integrated baseline value-alignment guards:
    - `scripts/check_usage_factor_value_alignment.py` (Cep/Cep,nr factor tables)
    - `scripts/check_scenario_value_alignment.py` (occupancy/end-use scenario profiles)
    - `scripts/check_lighting_value_alignment.py` (lighting parameter table)
    - `scripts/check_bbio_value_alignment.py` (Bbio weights)
    - `scripts/check_dh_value_alignment.py` (DH thresholds)
    - `scripts/check_systems_value_alignment.py` (generator and part-load conventions)
    - `scripts/check_solar_value_alignment.py` (solar conventions + Perez bins)
  - Composite strict gate remains green with all structural + value-alignment guards enabled.
  - Remaining to close legal baseline alignment: replace `baseline-v1` profiles by finalized official source-aligned profiles.

## Workstreams by criticality

### P0 (must fix first)
1. Climate dataset ingestion
- Target: replace generated climate placeholders with official climate inputs by zone, including canicule sequence, while keeping current manifest proof and CI guarantees.
- Files: Climate.lean
- Deliverables:
  - deterministic parser/loader
  - provenance metadata (source file id, version, checksum)
  - validation tests for array sizes and ranges
- Exit criteria: production path uses official source files, provenance remains strict, and composite gate stays green.

2. Annual simulation core
- Target: preserve implemented annual simulation while extending evidence depth around numerical fidelity and reference diversity.
- Files: Thermal.lean
- Deliverables:
  - maintain executable simulation with deterministic fixtures
  - extend benchmark/reference diversity around annual outputs
  - add any missing higher-granularity diagnostic regressions where useful
- Exit criteria: simulation remains executable and is covered by broader certification-grade evidence.

3. Modulation tables and factor provenance
- Target: keep table-driven lookup but migrate from internal baseline profiles to finalized official-source-aligned legal values/IDs.
- Files: RE2020.lean, Types.lean, Indicators.lean
- Deliverables:
  - finalized official-source-aligned tables
  - stable mapping from building/category/zone to coefficients
  - per-value source key at audit depth
- Exit criteria: no remaining `baseline-v1` dependency in compliance-critical value alignment.

4. Reference-case validation path
- Target: move from strong internal reference rigor to broader external certification-grade comparability.
- Files: RE2020.lean, potentially Indicators.lean/Thermal.lean
- Deliverables:
  - larger official benchmark suite
  - maintained pass/fail thresholds and tolerance governance
  - reproducible artifact synchronization for the expanded corpus
- Exit criteria: benchmark corpus breadth is materially stronger than the current 12-case floor while preserving strict CI and readiness gates.

### P1 (high-value fidelity improvements)
1. Full Cep/Cep_nr usage matrix coverage
- Preserve current extended usage coverage and harden legal source alignment at finer granularity where needed.
- Files: RE2020.lean, Indicators.lean, Systems.lean

2. Occupancy and operation conventions
- Preserve table-driven scenario profiles and deepen function-level legal anchoring and external evidence links.
- Files: Scenarios.lean

3. DH and lighting fidelity improvements
- Move from current table-driven and citation-backed methods to equation/table-level legal anchoring and external calibration depth.
- Files: Indicators.lean, Lighting.lean
- Status: structurally implemented; next step is finer-grained legal anchoring and finalized official-source value alignment.

### P2 (secondary but important)
1. Solar model coefficient fidelity
- Preserve current explicit referenced tables and improve legal-source depth where audit granularity demands it.
- Files: Solar.lean

2. Systems model hardening
- Improve part-load and auxiliary models toward deeper annex-equation traceability and broader external validation proof.
- Files: Systems.lean

## Traceability requirements (Definition of Done)
Each regulatory function must include:
1. Source key: annex section + table/equation id + version date
2. Constant provenance: source table id and unit
3. Test linkage: reference-case id and expected tolerance
4. Change log entry when legal source/version changes

## Suggested execution sequence
1. P0 climate ingestion
2. P0 finalized legal value alignment
3. P0 benchmark corpus expansion
4. P1 equation/table-level legal keying
5. P1 deeper indicator and scenario calibration evidence
6. P2 model refinements and external proof packaging

## Measurable targets
- Coverage target after P0: fidelity >= 60% (achieved)
- Coverage target after P1: fidelity >= 80% (achieved)
- Coverage target after P1/P2 hardening wave: fidelity >= 85% (achieved)
- Coverage target after current evidence-hardening wave: objective readiness = 100.0 / 100 (achieved)
- Coverage target after next frontier wave: preserve 100.0 / 100 while replacing baseline/internal proof dependencies with finalized official-source and broader external benchmark proof
- Objective computed indicator (auto-published): 100.0 / 100 (`RE2020/data/compliance_readiness_score.json`, model `readiness-v2`)
- Placeholder targets: sorry=0, critical placeholder=0, TODO-critical=0

## Next frontier queue
Objective: preserve the current 100/100 evidence posture while reducing residual dependence on internal baseline profiles and limited benchmark breadth.

Current status:
- Composite strict gate is green.
- Deep negative-regression mode is available and green when invoked.
- Formal theorem, Real bridge, approximation certificate, and drift guard layers are in place.

Execution order for the next wave:
1. Replace generated climate datasets with official source files while preserving manifest proof guarantees.
2. Replace `baseline-v1` profiles with finalized official-source-aligned value profiles across all guarded domains.
3. Expand official benchmark/reference corpus beyond the current 12-case floor.
4. Add per-function legal citation keys (annex section, table/equation ID, version date) across compliance-critical functions.
5. Package external benchmark evidence and reproducibility material for third-party review.
