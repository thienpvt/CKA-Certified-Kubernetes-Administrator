#!/bin/bash
# cka-sim/tests/cases/baseline_capture_smoke.sh — verifies cka_sim::baseline::is_candidate_modified.
# TDD RED: this case MUST fail until lib/baseline.sh is implemented.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# ---------- PASS (back-compat): unset CKA_SIM_BASELINE_PATH -> returns 0 ----------
unset CKA_SIM_BASELINE_PATH 2>/dev/null || true
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-changed"
cka_sim::baseline::is_candidate_modified pod foo -n bar
rc=$?
expect_eq "$rc" "0" "back-compat: returns 0 when CKA_SIM_BASELINE_PATH unset" || case_failed=1

# ---------- PASS (resource not in baseline): pod/foo not in resource_list -> returns 0 ----------
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/baseline-stub/baseline.json"
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-changed"
cka_sim::baseline::is_candidate_modified pod foo -n bar
rc=$?
expect_eq "$rc" "0" "not-in-baseline: returns 0 (candidate-authored)" || case_failed=1

# ---------- PASS (delta via generation): deployment/web gen=3->4 -> returns 0 ----------
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-changed"
cka_sim::baseline::is_candidate_modified deployment web -n test-ns
rc=$?
expect_eq "$rc" "0" "gen-delta: returns 0 (generation 4 > 3)" || case_failed=1

# ---------- PASS (delta via rv fallback): configmap/app-config gen=null, rv differs -> returns 0 ----------
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/configmap-app-config-changed"
cka_sim::baseline::is_candidate_modified configmap app-config -n test-ns
rc=$?
expect_eq "$rc" "0" "rv-fallback: returns 0 (generation null, rv 600 != 500)" || case_failed=1

# ---------- FAIL (unchanged): deployment/web gen=3 rv=100 both same -> returns 1 ----------
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-unchanged"
cka_sim::baseline::is_candidate_modified deployment web -n test-ns
rc=$?
expect_eq "$rc" "1" "unchanged: returns 1 (gen=3 rv=100 same as baseline)" || case_failed=1

exit "$case_failed"
