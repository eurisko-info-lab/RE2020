# Legal Keying Rollout Plan

## Objective
Add equation/table-level legal keys to compliance-critical code paths so each regulated constant or transformation is traceable to a precise legal anchor.

## Target metadata shape
Each compliance-critical function or table-backed rule should expose, directly or via exported metadata:
1. annex section
2. table ID
3. equation ID
4. version date
5. source document label

## First rollout scope
1. `Indicators.calculateBbio`
2. `Indicators.calculateCep`
3. `Indicators.calculateCepNr`
4. `Indicators.calculateDHFromCanicule`
5. `RE2020.defaultModulations`
6. table-backed lookups in `RegulationTables.lean`
7. scenario/profile lookups in `Scenarios.lean`

## Rollout mechanics
1. Extend citation structures where needed so they can carry section/table/equation keys explicitly.
2. Preserve backward compatibility for existing exported JSON artifacts.
3. Add script-level guards that fail when a required key field is missing.
4. Surface the new keys in human-readable documentation and machine-readable exports.

## Suggested schema addition
Minimal required fields per anchor:
- `annexSection`
- `tableId`
- `equationId`
- `versionDate`
- `sourceDoc`

## Validation path
1. Add required-field checks to structural guards.
2. Regenerate exports.
3. Verify strict composite gate remains green.
4. Update traceability matrix language from high-level anchors to fine-grained anchors where applicable.

## Success criteria
1. Auditors can navigate from a regulated value or formula to its legal key without free-text interpretation.
2. Exported artifacts contain those keys for downstream review tooling.
3. Repository documentation can claim equation/table-level trace depth with evidence.