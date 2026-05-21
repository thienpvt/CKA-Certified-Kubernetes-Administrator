#!/bin/bash
# cka-sim/scripts/lint-question-symptom.sh — Phase 15 CI-01 (refactored Phase 16).
# Per-question symptom-diff: source setup.sh, capture kubectl state,
# diff against expected-symptom.yaml. Pure bash + jq + python3 yaml.
#
# Diff core lives in cka-sim/lib/symptom-diff.sh (Phase 16 BASELINE-01 extract).
# This script is now a thin driver that walks expected-symptom.yaml files
# and delegates per-question work to cka_sim::symptom_diff::run_one with
# ns_prefix='lint'.
#
# Usage:
#   bash cka-sim/scripts/lint-question-symptom.sh                 # all questions
#   bash cka-sim/scripts/lint-question-symptom.sh storage/01-pvc-binding  # one
#
# Exit codes:
#   0 = clean diff (or no live cluster; warn-skip)
#   1 = at least one question diverged from its expected-symptom.yaml
set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CKA_SIM_ROOT/.." && pwd)"
export CKA_SIM_ROOT REPO_ROOT

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../lib/symptom-diff.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/symptom-diff.sh"

header "live-cluster symptom diff"

# --- Cluster preflight gate -----------------------------------------------
if ! kubectl cluster-info >/dev/null 2>&1; then
  warn "no live cluster reachable (kubectl cluster-info failed) — skipping symptom-diff"
  exit 0
fi

# --- Tool preflight --------------------------------------------------------
command -v jq >/dev/null 2>&1 || die "jq not found in PATH"
command -v python3 >/dev/null 2>&1 || die "python3 not found in PATH"
python3 -c 'import yaml' 2>/dev/null || die "python3 yaml module not available"

# --- Driver ---------------------------------------------------------------
errors=0
checked=0
target_arg="${1:-}"

while IFS= read -r yaml_file; do
  q_dir="$(dirname "$yaml_file")"
  pack="$(basename "$(dirname "$q_dir")")"
  q_name="$(basename "$q_dir")"
  if [[ -n "$target_arg" && "$pack/$q_name" != "$target_arg" ]]; then
    continue
  fi
  if cka_sim::symptom_diff::is_unsupported_on_kind "$q_dir"; then
    warn "$pack/$q_name: skipped (unsupported-on-kind)"
    continue
  fi
  if cka_sim::symptom_diff::is_unsupported_in_audit_mode "$q_dir"; then
    warn "$pack/$q_name: skipped (unsupported-in-audit-mode)"
    continue
  fi
  checked=$(( checked + 1 ))
  info "==> $pack/$q_name"
  if ! cka_sim::symptom_diff::run_one "$yaml_file" "$q_dir" "$pack" "$q_name" "lint"; then
    errors=$(( errors + 1 ))
  fi
done < <(find "$CKA_SIM_ROOT/packs" -name 'expected-symptom.yaml' -type f | sort)

if [[ -n "$target_arg" && "$checked" -eq 0 ]]; then
  warn "no expected-symptom.yaml matched filter '$target_arg'"
  exit 0
fi

if (( errors > 0 )); then
  err "$errors question(s) had symptom-diff failures across $checked checked"
  exit 1
fi
ok "symptom diff: $checked question(s) passed"
