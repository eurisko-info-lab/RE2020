# External Benchmark Report Pack

## Objective
Prepare a publishable benchmark bundle that third parties can review and reproduce without hidden internal steps.

## Pack contents
1. Corpus definition
   - case IDs
   - category/climate coverage
   - source URIs and checksums
2. Methodology
   - indicator definitions used for comparison
   - tolerance policy
   - assumptions and exclusions
3. Reproduction recipe
   - exact commands to run
   - expected generated artifacts
4. Result summary
   - per-case pass/fail
   - aggregate pass rates
   - delta trends across releases
5. Signed artifact set
   - exported evidence files
   - report version tag
   - source fingerprint or content hash where applicable

## Current repository assets already usable
1. `RE2020/data/compliance_readiness_score.json`
2. `RE2020/data/validation/cases/`
3. `RE2020/data/formal_approx_certificate.json`
4. `docs/REGULATION_TRACEABILITY_MATRIX.md`
5. `scripts/check_compliance_gate.py`

## Missing before external publication
1. larger official benchmark corpus
2. a versioned report layout summarizing benchmark outcomes across releases
3. a release-time process for attaching the pack to published artifacts

## Reproduction recipe skeleton
1. `lake build`
2. `python3 scripts/check_compliance_gate.py --strict-legal-catalog`
3. `python3 scripts/check_compliance_gate.py --strict-legal-catalog --include-negative-regression`
4. archive generated evidence artifacts and report tables

## Success criteria
1. A third party can reproduce the published claims from the repository and released artifacts.
2. The report pack is stable enough to attach to release notes or diligence materials.