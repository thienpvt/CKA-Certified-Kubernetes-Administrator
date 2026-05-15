#!/bin/bash
# cka-sim/tests/cases/grade_assert_changed_since_setup.sh — verifies cka_sim::grade::assert_changed_since_setup.
# TDD RED: this case MUST fail until lib/baseline.sh + grade helpers are implemented.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

# Reset accumulators
CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
CKA_SIM_GRADE_TRAPS=()

case_failed=0

# ---------- Case A (PASS via generation): baseline gen=3, current gen=4 ----------
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/baseline-stub/baseline.json"
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-changed"
cka_sim::grade::assert_changed_since_setup deployment web -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "case-A: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "1" "case-A: PASSED incremented (generation 4 > 3)" || case_failed=1

# ---------- Case B (PASS via rv fallback): configmap gen=null, rv differs ----------
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/configmap-app-config-changed"
cka_sim::grade::assert_changed_since_setup configmap app-config -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "2" "case-B: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "2" "case-B: PASSED incremented (rv fallback: 600 != 500)" || case_failed=1

# ---------- Case C (FAIL): baseline gen=3 rv=100, current gen=3 rv=100 ----------
CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-unchanged"
cka_sim::grade::assert_changed_since_setup deployment web -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "case-C: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "0" "case-C: PASSED NOT incremented (unchanged)" || case_failed=1
expect_eq "${#CKA_SIM_GRADE_FAILS[@]}" "1" "case-C: FAILS appended" || case_failed=1

# ---------- Case D (BACK-COMPAT): no baseline path -> FAIL ----------
CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
unset CKA_SIM_BASELINE_PATH
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-changed"
cka_sim::grade::assert_changed_since_setup deployment web -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "case-D: TOTAL incremented (back-compat)" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "0" "case-D: PASSED=0 (no baseline -> fail)" || case_failed=1
expect_eq "${#CKA_SIM_GRADE_FAILS[@]}" "1" "case-D: FAILS appended (no baseline)" || case_failed=1

exit "$case_failed"
