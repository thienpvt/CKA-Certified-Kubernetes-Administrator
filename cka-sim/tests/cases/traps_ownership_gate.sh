#!/bin/bash
# cka-sim/tests/cases/traps_ownership_gate.sh — verifies per-resource detectors gate on baseline ownership.
# TDD RED: this case MUST fail until traps.sh detectors are refactored to call is_candidate_modified.
#
# Cases:
#   A (Q3 REGRESSION FIX): setup-owned pod unchanged -> detector returns EMPTY (no trap fired).
#   B (candidate-modified): same pod rv bumped -> detector fires "default-sa-used".
#   C (candidate-authored): pod NOT in baseline -> detector fires "default-sa-used".
#   D (back-compat): CKA_SIM_BASELINE_PATH unset -> detector fires freely (old behavior).
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# ---------- Case A (Q3 REGRESSION FIX): pod in baseline, unchanged (gen=1 rv=100) -> EMPTY ----------
# The detector must NOT fire on a setup-owned pod that the candidate never touched.
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/ownership-gate/baseline.json"
export CKA_SIM_TEST_CURRENT="grading-honesty/ownership-gate/pod-setup-owned"
r=$(cka_sim::trap::detect_default_sa_used test-ns web-abc123 || true)
expect_empty "$r" "Case A (Q3 regression): setup-owned unchanged pod -> no trap fired" || case_failed=1

# ---------- Case B (candidate-modified): pod in baseline, rv bumped (100->200) -> fires ----------
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/ownership-gate/baseline.json"
export CKA_SIM_TEST_CURRENT="grading-honesty/ownership-gate/pod-candidate-modified"
r=$(cka_sim::trap::detect_default_sa_used test-ns web-abc123 || true)
expect_eq "$r" "default-sa-used" "Case B: candidate-modified pod with default SA -> fires" || case_failed=1

# ---------- Case C (candidate-authored): pod NOT in baseline -> fires ----------
# Use a pod name that is NOT in baseline.resource_list ("pod/web-abc123" is the only entry).
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/ownership-gate/baseline.json"
export CKA_SIM_TEST_CURRENT="grading-honesty/ownership-gate/pod-candidate-modified"
r=$(cka_sim::trap::detect_default_sa_used test-ns new-pod-xyz || true)
expect_eq "$r" "default-sa-used" "Case C: candidate-authored pod (not in baseline) -> fires" || case_failed=1

# ---------- Case D (back-compat): CKA_SIM_BASELINE_PATH unset -> fires freely ----------
unset CKA_SIM_BASELINE_PATH 2>/dev/null || true
export CKA_SIM_TEST_CURRENT="grading-honesty/ownership-gate/pod-setup-owned"
r=$(cka_sim::trap::detect_default_sa_used test-ns web-abc123 || true)
expect_eq "$r" "default-sa-used" "Case D: no baseline (back-compat) -> fires freely" || case_failed=1

exit "$case_failed"
