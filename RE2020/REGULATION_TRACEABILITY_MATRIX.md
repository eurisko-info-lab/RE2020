# RE2020 Traceability Matrix (Code vs Regulation)

## Scope
- Codebase: RE2020/*.lean
- Claimed sources in code comments: RE2020 / Th-BCE 2020, Arrete du 4 aout 2021 (Annexe II/III), RE2020 guide
- Assessment basis: repository evidence only (no external legal text parsing in this audit)

## Status legend
- Implemented: executable algorithm in active pipeline, no placeholder marker
- Partial: executable but simplified/heuristic or missing table-driven regulatory data
- Missing: placeholder, sorry, TODO-critical, or not wired in pipeline

## Annex-anchor matrix

| Domain | Claimed legal anchor | Code anchor | Status | Evidence |
|---|---|---|---|---|
| Climate datasets | Annexe III climate conventions + canicule sequence | Climate.lean:loadClimateData | Missing | Explicit placeholder synthetic arrays; no official file reader |
| Annual thermal simulation | Th-BCE hourly annual simulation logic | Thermal.lean:simulateYear | Missing | Function body is `sorry` |
| Bbio indicator | Annexe II/III indicator method | Indicators.lean:calculateBbio | Partial | Formula present, but modulation tables not encoded |
| Cep indicator | Annexe II/III indicator method | Indicators.lean:calculateCep | Partial | Formula present, but pipeline in RE2020.lean uses simplified usage list |
| Cep,nr indicator | Annexe II/III indicator method | Indicators.lean:calculateCepNr | Partial | Formula present, but non-renewable vectors are simplified defaults |
| DH indicator | Annexe canicule/discomfort logic | Indicators.lean:calculateDHFromCanicule | Partial | Adaptive threshold and occupancy usage are simplified |
| Modulation coefficients | Guide/annex coefficient tables | RE2020.lean:defaultModulations | Missing | All coefficients hardcoded to 0.0 |
| Occupancy and operation conventions | Th-BCE scenario conventions | Scenarios.lean:residentialScenario/officeScenario | Partial | Simplified daily profiles, no explicit table provenance |
| Lighting method | RE2020 lighting needs path | Lighting.lean + Indicators.lean:computeLightingNeeds | Partial | Lighting module exists, but pipeline wrapper uses area*0.08 heuristic |
| Solar gains | Annexe III solar conventions | Solar.lean core functions | Partial | Multiple comments mark simplified models/coefficients |
| Systems and auxiliaries | Annexe III systems logic | Systems.lean | Partial | Broad coverage exists, with many simplified models |
| Validation against references | Official case benchmarking (CSTB-like) | RE2020.lean:runValidationScenario | Missing | Thermal bridge impact is placeholder 0.0 |

## Reference completeness (article/table mapping)

Current state:
- High-level references exist (Annexe II/III, Th-BCE, guide).
- Exact legal anchors are not encoded at equation/table granularity.

What is missing for complete references:
1. Per-function legal citation key (annex section, table ID, equation ID, version date).
2. Source provenance fields for constants (e.g., modulation, primary factors).
3. Validation linkage to official benchmark case IDs.

## Quantitative code signals
- simplified markers (`simplifi*`): 20
- placeholder markers (`placeholder`): 4
- TODO markers: 1
- proof/runtime placeholders (`sorry`): 2
- explicit legal-reference mentions (`Annexe`, `arrete`, `Guide RE2020`, `Th-BCE`): 19

## Coverage estimate (engineering judgement)
- Domain/module coverage: ~70%
- Executable regulatory fidelity (audit/certification readiness): ~35%

Rationale:
1. Core annual engine unresolved (simulateYear).
2. Climate source ingestion unresolved (official datasets not wired).
3. Indicator pipeline currently simplified for uses, factors, and occupancy coupling.
4. No equation/table-level legal traceability metadata in code.

## Immediate compliance blockers
1. Thermal.lean:simulateYear (remove sorry, verify hourly state transitions).
2. Climate.lean:loadClimateData (official dataset ingestion + reproducible parser).
3. RE2020.lean:defaultModulations and indicator factors (replace defaults with referenced tables).
4. RE2020.lean validation path (replace thermal bridge placeholder with implemented method).

## Governance recommendation
- Keep this file versioned as compliance evidence.
- Require each regulatory function to include: source citation key, constants provenance, and linked reference tests.
