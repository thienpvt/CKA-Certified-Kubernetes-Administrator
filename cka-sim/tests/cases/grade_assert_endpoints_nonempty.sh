#!/bin/bash
# cka-sim/tests/cases/grade_assert_endpoints_nonempty.sh — verifies cka_sim::grade::assert_endpoints_nonempty.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
CKA_SIM_GRADE_TRAPS=()

case_failed=0

# ---------- pass: endpoints has 2 addresses ----------
export CKA_SIM_TEST_CURRENT="assert_endpoints_nonempty/pass"
cka_sim::grade::assert_endpoints_nonempty cka-sim-test web || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "pass: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "1" "pass: PASSED incremented" || case_failed=1

# ---------- fail: endpoints has no subsets ----------
export CKA_SIM_TEST_CURRENT="assert_endpoints_nonempty/fail"
cka_sim::grade::assert_endpoints_nonempty cka-sim-test web || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "2" "fail: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "1" "fail: PASSED NOT incremented" || case_failed=1
expect_eq "${#CKA_SIM_GRADE_FAILS[@]}" "1" "fail: FAILS appended once" || case_failed=1

exit "$case_failed"
