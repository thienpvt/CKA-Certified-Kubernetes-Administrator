#!/bin/bash
# cka-sim/tests/cases/grade_assert_generation_delta_ge.sh — verifies cka_sim::grade::assert_generation_delta_ge.
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

export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/baseline-stub/baseline.json"

# ---------- PASS: baseline gen=3, current gen=5, threshold=2 -> delta=2 >= 2 ----------
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-gen5"
cka_sim::grade::assert_generation_delta_ge deployment web 2 -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "pass: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "1" "pass: PASSED incremented (delta=2 >= 2)" || case_failed=1

# ---------- FAIL: baseline gen=3, current gen=4, threshold=2 -> delta=1 < 2 ----------
CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-changed"
cka_sim::grade::assert_generation_delta_ge deployment web 2 -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "fail: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "0" "fail: PASSED NOT incremented (delta=1 < 2)" || case_failed=1
expect_eq "${#CKA_SIM_GRADE_FAILS[@]}" "1" "fail: FAILS appended" || case_failed=1

# ---------- FAIL: resource not in baseline -> delta undefined -> fail ----------
CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/deployment-web-changed"
cka_sim::grade::assert_generation_delta_ge deployment nonexistent 1 -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "not-in-baseline: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "0" "not-in-baseline: PASSED=0 (resource not in baseline)" || case_failed=1
expect_eq "${#CKA_SIM_GRADE_FAILS[@]}" "1" "not-in-baseline: FAILS appended" || case_failed=1

exit "$case_failed"
