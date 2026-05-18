#!/bin/bash
# Phase 07.1 grading-honesty regression: workloads-scheduling/04-hpa-metrics-server
# Asserts empty submission (post-setup, no HPA) scores 0/7 AND ref-solution scores 7/7.
# RESEARCH Q5 prediction: LOW (candidate creates HPA + installs metrics-server).
# Audit verdict: assert_resource_exists hpa -> assert_resource_candidate_authored (stricter).
# Test infra: CKA_SIM_GRADE_TOP_RETRIES=1 + CKA_SIM_GRADE_TOP_SLEEP=0 short-circuit the
# 12-iter retry loop (audit-escape D-22 documented in 07.1-09-AUDIT-ESCAPE.md).
# Phase 13 BUG-M06: grader gained Assertions 5 (target.type=Utilization) and 6
# (averageUtilization=50). Empty 0/5 → 0/7, ref 5/5 → 7/7.
# Phase 13 BUG-M10: A7 (kubectl top pod) now gated on (HPA exists AND candidate-authored).

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="workloads-scheduling"
slug="04-hpa-metrics-server"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# Fast-mode overrides for the metrics-server retry loop (stub never serves real metrics).
export CKA_SIM_GRADE_TOP_RETRIES=1
export CKA_SIM_GRADE_TOP_SLEEP=0

# ----- empty submission test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-workloads-scheduling-04"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/7"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  exit 1
fi

# ----- ref-solution test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 7/7"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  exit 1
fi
