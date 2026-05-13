#!/bin/bash
# Run all remaining UAT tests across all phases.
# Usage: bash cka-sim/tests/run-all-uat.sh
#
# Prerequisites:
#   - On the control-plane node with the repo cloned
#   - Cluster healthy (cka-sim doctor passes)
#   - SSH to workers works (for Phase 1 tests — skipped if not)
#
# Phases covered:
#   Phase 4: Storage + Workloads-Scheduling live drills (2 pending)
#   Phase 7: Exam mode end-to-end (4 pending, 2 interactive-only)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CKA_SIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export CKA_SIM_ROOT

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"

header "═══ CKA-SIM Full UAT Suite ═══"
printf '\n'

total_phases=0
passed_phases=0
failed_phases=0

run_phase_uat() {
  local phase="$1" script="$2"
  total_phases=$((total_phases+1))
  header "Phase $phase UAT"
  if bash "$script"; then
    passed_phases=$((passed_phases+1))
    ok "Phase $phase: ALL PASS"
  else
    failed_phases=$((failed_phases+1))
    err "Phase $phase: FAILURES (see above)"
  fi
  printf '\n'
}

# ─────────────────────────────────────────────────────────────────────
# Phase 4: Storage + Workloads-Scheduling live drills
# ─────────────────────────────────────────────────────────────────────
run_phase_uat 4 "$SCRIPT_DIR/phase4-uat.sh"

# ─────────────────────────────────────────────────────────────────────
# Phase 7: Exam Mode + Blueprint Alpha + Reporting
# ─────────────────────────────────────────────────────────────────────
run_phase_uat 7 "$SCRIPT_DIR/phase7-uat.sh"

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────
printf '\n'
header "═══ UAT Summary ═══"
printf 'Phases tested: %d  Passed: %d  Failed: %d\n' "$total_phases" "$passed_phases" "$failed_phases"

if (( failed_phases == 0 )); then
  ok "All UAT phases passed!"
  printf '\n'
  info "Interactive tests still need manual verification:"
  info "  Phase 7 Test 1: Timer renders (visual check)"
  info "  Phase 7 Test 2: Ctrl-C/Ctrl-Z signals (interactive)"
  info ""
  info "To verify interactively:"
  info "  bash cka-sim/bin/cka-sim exam blueprint-alpha"
  exit 0
else
  err "$failed_phases phase(s) had failures."
  exit 1
fi
