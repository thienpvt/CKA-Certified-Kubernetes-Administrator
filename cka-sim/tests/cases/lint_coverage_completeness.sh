#!/bin/bash
# cka-sim/tests/cases/lint_coverage_completeness.sh -- Task 04-03 Task 2 unit case.
# Asserts lint-coverage.sh exits 1 with the expected error message when a
# tracker-referenced question-id is missing from the manifest and when a
# tracker slug has an empty questions list.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0
fixtures="$CKA_SIM_ROOT/tests/fixtures/lint-coverage"

out=$(CKA_SIM_LINT_PACKS_DIR="$fixtures" bash "$CKA_SIM_ROOT/scripts/lint-coverage.sh" missing-question 2>&1); rc=$?
expect_eq "$rc" "1" "missing-question fixture: lint fails" || case_failed=1
expect_contains "$out" "not in manifest.yaml" "missing-question: error mentions manifest mismatch" || case_failed=1

out=$(CKA_SIM_LINT_PACKS_DIR="$fixtures" bash "$CKA_SIM_ROOT/scripts/lint-coverage.sh" empty-tracker 2>&1); rc=$?
expect_eq "$rc" "1" "empty-tracker fixture: lint fails" || case_failed=1
expect_contains "$out" "empty questions list" "empty-tracker: error mentions empty list" || case_failed=1

exit "$case_failed"
