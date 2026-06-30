# RE2020 Battlefield Scorecard

## Purpose
This document is a competitor-style scorecard based only on repository evidence, intended for technical strategy, audits, and investor discussions.

Snapshot date: 2026-06-30

## Evidence Inputs
- Objective readiness model: `RE2020/data/compliance_readiness_score.json`
- Traceability posture: `docs/REGULATION_TRACEABILITY_MATRIX.md`
- Gap/risk roadmap: `docs/REGULATION_GAP_CLOSURE_ROADMAP.md`
- CI hard gate wiring: `.github/workflows/re2020-build.yml`
- Release pipeline wiring: `.github/workflows/re2020-release.yml`
- Formal approximation certificate: `RE2020/data/formal_approx_certificate.json`
- Current implementation scale snapshot: `cloc RE2020` -> 22 Lean files / 4,930 Lean LOC in `RE2020/`, 49 tracked files in scope snapshot, 32,489 total LOC across the counted repo subset

## Snapshot Summary
- Readiness score: 100.0 / 100 (`readiness-v2`)
- Qualification gates passed: 4 / 4
- Guard wiring coverage: 21 / 21 required checks present
- Citation catalog finalization: 59 / 59 required IDs finalized
- Official-calibrated benchmark corpus: 12 / 12 cases with local evidence artifacts
- Approximation certificate corpus: 15 result files / 45 indicator samples

## Scoring Framework (0-100)
Dimension weights:
1. Regulatory coverage and traceability: 30
2. Validation and provenance rigor: 25
3. CI guardrail strength and anti-drift posture: 20
4. Formal assurance depth: 15
5. Operational maturity signals: 10

Interpretation bands:
- 85-100: frontier-grade engineering posture
- 70-84: strong but with material hardening gaps
- 50-69: workable MVP / pre-audit posture
- <50: high compliance and audit risk

## Filled Scorecard (Current Repository State)

### 1) Regulatory coverage and traceability (30)
- Evidence:
  - Annex-anchor matrix now treats all tracked domains as implemented in the current evidence view.
  - No placeholder/sorry/TODO markers in compliance-critical paths.
  - Table-driven, citation-backed controls are enforced across climate, modulation, usage factors, scenarios, lighting, DH, systems, and solar.
- Score: 29/30
- Why not 30: matrix still lists outstanding deep legal granularity items (equation-level keying), which is a minor deduction.
- Primary evidence links:
  - `docs/REGULATION_TRACEABILITY_MATRIX.md`
  - `RE2020/data/regulation_tables_export.json`
  - `RE2020/data/scenario_profiles_export.json`

### 2) Validation and provenance rigor (25)
- Evidence:
  - `readiness-v2` overall 100 with 4/4 qualification gates passed.
  - 12/12 official-calibrated benchmark cases with source URI+checksum and local reproducible evidence artifacts.
  - Official source proof is complete at the current gate level (dataset coverage, source URI coverage, source digest coverage, calibrated tolerance coverage).
- Score: 24/25
- Why not 25: benchmark breadth is strong for rigor, but still modest for broad market comparability.
- Primary evidence links:
  - `RE2020/data/compliance_readiness_score.json`
  - `RE2020/data/validation/cases/`

### 3) CI guardrail strength and anti-drift posture (20)
- Evidence:
  - Composite strict gate wired in CI workflow.
  - Value-alignment + traceability checks across domains.
  - Formal approximation certificate generation, validation, and drift guard integrated.
  - Deep negative-regression mode exists for anti-gaming verification.
- Score: 20/20
- Primary evidence links:
  - `.github/workflows/re2020-build.yml`
  - `scripts/check_compliance_gate.py`
  - `scripts/check_validation_evidence_negative_regression.py`

### 4) Formal assurance depth (15)
- Evidence:
  - Nat theorem layer fully proved.
  - Real bridge layer present.
  - Approximation-certificate bridge and drift guard implemented.
  - Formal Float-to-Real governance is explicit rather than implicit.
- Score: 14/15
- Why not 15: bridge to Float remains certificate-driven rather than native Float theoremization.
- Primary evidence links:
  - `RE2020/FormalTheorems.lean`
  - `RE2020/FormalRealBridge.lean`
  - `RE2020/FormalApproxBridge.lean`
  - `RE2020/data/formal_approx_certificate.json`

### 5) Operational maturity signals (10)
- Evidence:
  - Deterministic gate scripts and reproducibility checks.
  - Lean + Python integrated CI.
  - Build, release, artifact-generation, and drift-sensitive exported evidence are wired into repository workflows.
  - `cloc` snapshot shows 22 Lean files / 4,930 Lean LOC in `RE2020/` and 32,489 total LOC in the counted repo subset.
- Score: 8/10
- Why not 10: no repository evidence of production deployment telemetry, SLA, or large public benchmark campaign.
- Primary evidence links:
  - `.github/workflows/re2020-build.yml`
  - `.github/workflows/re2020-release.yml`
  - `scripts/run_compliance_modes.sh`

## Aggregate Result
- Total score: 95/100
- Band: frontier-grade engineering posture

## Executive Read
- Best-in-class signals in this repository: traceability discipline, CI guard density, reproducible evidence posture, and formal assurance layering.
- Main remaining handicap versus top commercial incumbents: external proof breadth, not internal engineering control.
- Strategic interpretation: this repo already looks stronger than most engineering-led RE2020 implementations, but still needs broader external evidence to dominate buyer perception.

## Relative Battlefield Position (Evidence-Based)
Estimated position versus typical RE2020 implementations:
1. Engineering rigor (traceability + CI + formal controls): top tier.
2. Auditability/reproducibility posture: top tier.
3. Market proof (external corpus breadth, certified deployment footprint): upper-mid tier.

Practical estimate:
- Technical posture percentile: top 10-20%
- Commercial proof percentile: top 30-50%

## Competitor Comparison Template (Keep for live use)
Use this table when you collect external evidence.

| Vendor / Tool | Regulatory coverage (30) | Validation & provenance (25) | CI & drift controls (20) | Formal assurance (15) | Operational signals (10) | Total | Evidence links |
|---|---:|---:|---:|---:|---:|---:|---|
| This repo (current) | 29 | 24 | 20 | 14 | 8 | 95 | `RE2020/data/compliance_readiness_score.json`; `docs/REGULATION_TRACEABILITY_MATRIX.md`; `RE2020/FormalTheorems.lean`; `.github/workflows/re2020-build.yml` |
| Incumbent black-box engine | TBD | TBD | TBD | TBD | TBD | TBD | collect certification scope, benchmark pack, release/process evidence |
| Engineering-heavy SaaS platform | TBD | TBD | TBD | TBD | TBD | TBD | collect public docs, benchmark notes, audit claims, CI/process evidence |
| Spreadsheet / consultancy workflow | TBD | TBD | TBD | TBD | TBD | TBD | collect methodology docs, update cadence, reproducibility evidence |

Scoring note for external rows:
- Leave `TBD` until the claim can be backed by public documentation, contractual audit material, or reproducible benchmark artifacts.

## Priority Moves to Extend Lead
1. Expand official benchmark corpus from 12 to 30+ cases with category/zone diversity and publish stable deltas over time.
2. Add equation/table-level legal keying metadata directly at function level for audit trace depth.
3. Publish an external benchmark report pack (methodology + reproducibility recipe + signed artifact set).
4. Add operational maturity artifacts (release cadence KPIs, defect escape rate, reproducibility SLA).
5. Translate the current internal 100/100 posture into a buyer-facing proof bundle rather than leaving the evidence repository-local.

## Caveats
- This scorecard is intentionally evidence-only and repository-local.
- The 95/100 score is a posture score, not a legal certification claim.
- External competitor scores must be populated from verifiable public or contractual evidence.
