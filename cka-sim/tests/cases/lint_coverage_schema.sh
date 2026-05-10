#!/bin/bash
# cka-sim/tests/cases/lint_coverage_schema.sh -- Task 04-03 Task 2 unit case.
# Asserts lint-coverage.sh exits 0 on the 'good' fixture and exits 0 with a
# warning on the 'orphan' fixture (orphan = non-fatal per PACK-07 design).
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0
fixtures="$CKA_SIM_ROOT/tests/fixtures/lint-coverage"

# good: all refs resolve, all trackers populated -> exit 0
out=$(CKA_SIM_LINT_PACKS_DIR="$fixtures" bash "$CKA_SIM_ROOT/scripts/lint-coverage.sh" good 2>&1); rc=$?
expect_eq "$rc" "0" "good fixture: lint-coverage exits 0" || case_failed=1
expect_contains "$out" "coverage schema OK" "good fixture: emits coverage schema OK" || case_failed=1

# orphan: manifest question not referenced -> warning but exit 0
out=$(CKA_SIM_LINT_PACKS_DIR="$fixtures" bash "$CKA_SIM_ROOT/scripts/lint-coverage.sh" orphan 2>&1); rc=$?
expect_eq "$rc" "0" "orphan fixture: warning non-fatal, exit 0" || case_failed=1
expect_contains "$out" "orphan" "orphan fixture: warning mentions 'orphan'" || case_failed=1

exit "$case_failed"
