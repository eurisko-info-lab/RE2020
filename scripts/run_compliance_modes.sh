#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

mode="${1:-strict}"

case "$mode" in
  strict)
    echo "Running strict compliance gate"
    (cd "$repo_root" && python3 scripts/check_compliance_gate.py --strict-legal-catalog)
    ;;
  deep)
    echo "Running deep compliance gate (with negative regression)"
    (cd "$repo_root" && python3 scripts/check_compliance_gate.py --strict-legal-catalog --include-negative-regression)
    ;;
  maintain)
    echo "Running maintenance sync + strict compliance gate"
    (
      cd "$repo_root" && \
      python3 scripts/sync_validation_evidence.py --maintain && \
      python3 scripts/check_compliance_gate.py --strict-legal-catalog
    )
    ;;
  help|-h|--help)
    cat <<'EOF'
Usage: scripts/run_compliance_modes.sh [strict|deep|maintain]

Modes:
  strict    Run strict legal compliance gate.
  deep      Run strict legal gate and include anti-gaming negative regression.
  maintain  Normalize/sync validation evidence then run strict legal gate.
EOF
    ;;
  *)
    echo "Usage: scripts/run_compliance_modes.sh [strict|deep|maintain]" >&2
    exit 2
    ;;
esac
