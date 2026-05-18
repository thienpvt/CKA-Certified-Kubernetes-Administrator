#!/bin/bash
# Phase 07.1 grading-honesty regression: storage/01-pvc-binding
# Phase 10 BUG-H01 reshape: 1 weight=1 → 3 weight=1 (PV nodeAffinity key/operator/required-terms)
# plus 2 weight=0 preconditions (PVC Bound, Pod q01-app-consumer Ready).
# Empty submission: 0/3 (preconditions: PVC Bound passes, Pod not Ready fails).
# Ref-solution: 3/3 + 2 preconditions both pass.

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="storage"
slug="01-pvc-binding"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# ----- empty submission test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-storage-01"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/3"

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
expected_ref_score="SCORE: 3/3"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  exit 1
fi
