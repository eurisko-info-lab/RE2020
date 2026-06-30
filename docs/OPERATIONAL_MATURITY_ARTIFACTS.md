# Operational Maturity Artifacts

## Objective
Document the operational signals that move the repository from a strong engineering prototype toward a governable product surface.

## Artifact set
1. Release cadence KPI
   - target release frequency
   - changelog discipline
2. Defect escape KPI
   - number of post-release compliance regressions
   - number of gate escapes detected after publication
3. Reproducibility SLA
   - maximum tolerated delay between code change and refreshed evidence artifacts
4. Artifact freshness policy
   - expected synchronization window for generated exports, score artifacts, and certificates
5. Incident handling note
   - owner, rollback trigger, and remediation steps for evidence drift or gate failures

## Immediate documentation targets
1. Extend release process documentation with artifact expectations.
2. Record evidence refresh expectations for generated JSON/Markdown artifacts.
3. Define what constitutes a compliance regression for changelog and incident review purposes.

## Candidate KPIs
1. strict gate pass rate on default branch
2. deep gate pass rate on scheduled or release runs
3. mean time to repair evidence drift failures
4. benchmark corpus growth over time
5. number of releases carrying a reproducibility pack

## Success criteria
1. A reviewer can see not only what the repository proves, but also how reliably those proofs are maintained release to release.
2. Operational claims become documentable with repository-native artifacts rather than conversation-only assurances.