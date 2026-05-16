#!/bin/bash
# cka-sim/tests/cases/grade_assert_resource_exists.sh — verifies cka_sim::grade::assert_resource_exists.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

# Reset accumulators to known state at start of each case.
CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
CKA_SIM_GRADE_TRAPS=()

case_failed=0

# ---------- pass: fixture exists, stub returns Pod/exists ----------
export CKA_SIM_TEST_CURRENT="assert_resource_exists/pass"
cka_sim::grade::assert_resource_exists Pod exists -n cka-sim-test || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "pass: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "1" "pass: PASSED incremented" || case_failed=1

# ---------- fail: point at a non-existent fixture; stub exits 1 + empty stdout ----------
export CKA_SIM_TEST_CURRENT="assert_resource_exists/missing"
cka_sim::grade::assert_resource_exists Pod absent -n cka-sim-test || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "2" "fail: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "1" "fail: PASSED NOT incremented" || case_failed=1
expect_eq "${#CKA_SIM_GRADE_FAILS[@]}" "1" "fail: FAILS appended once" || case_failed=1

exit "$case_failed"
