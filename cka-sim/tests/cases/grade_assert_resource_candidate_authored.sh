#!/bin/bash
# cka-sim/tests/cases/grade_assert_resource_candidate_authored.sh — verifies cka_sim::grade::assert_resource_candidate_authored.
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

# ---------- PASS: storageclass/fast-ssd IS in baseline -> fail (pre-existed) ----------
# Wait -- storageclass/fast-ssd IS in baseline.resource_list, so this should FAIL.
# The PASS case is a resource NOT in baseline that currently exists.
# We need a fixture for a resource that exists but is NOT in baseline.
# Use a "pod/foo" which is not in baseline.resource_list, and kubectl get returns it.
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/storageclass-fast-ssd"
# This tests: resource NOT in baseline + kubectl get returns non-empty -> PASS
# We'll use kind=pod name=newpod which is not in baseline.resource_list
# But the kubectl stub uses CKA_SIM_TEST_CURRENT for the fixture path regardless of args.
# So we point at a fixture that returns a valid resource.
cka_sim::grade::assert_resource_candidate_authored pod newpod -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "pass: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "1" "pass: PASSED (not in baseline + exists)" || case_failed=1

# ---------- FAIL (in baseline): storageclass/fast-ssd is in baseline -> fail ----------
CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/storageclass-fast-ssd"
cka_sim::grade::assert_resource_candidate_authored storageclass fast-ssd || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "in-baseline: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "0" "in-baseline: PASSED=0 (resource pre-existed)" || case_failed=1
expect_eq "${#CKA_SIM_GRADE_FAILS[@]}" "1" "in-baseline: FAILS appended" || case_failed=1

# ---------- FAIL (not exists): resource not in baseline AND kubectl get returns empty ----------
CKA_SIM_GRADE_TOTAL=0
CKA_SIM_GRADE_PASSED=0
CKA_SIM_GRADE_FAILS=()
CKA_SIM_GRADE_PASSES=()
# Point at a non-existent fixture so kubectl stub exits 1 (resource doesn't exist)
export CKA_SIM_TEST_CURRENT="grading-honesty/baseline-stub/nonexistent-resource"
cka_sim::grade::assert_resource_candidate_authored pod missingpod -n test-ns || true
expect_eq "$CKA_SIM_GRADE_TOTAL" "1" "not-exists: TOTAL incremented" || case_failed=1
expect_eq "$CKA_SIM_GRADE_PASSED" "0" "not-exists: PASSED=0 (resource does not exist)" || case_failed=1
expect_eq "${#CKA_SIM_GRADE_FAILS[@]}" "1" "not-exists: FAILS appended" || case_failed=1

exit "$case_failed"
