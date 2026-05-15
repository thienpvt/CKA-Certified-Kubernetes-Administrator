#!/bin/bash
# Phase 07.1 grading-honesty regression: services-networking/06-netpol-endport
# Asserts empty submission (post-setup state) scores 1/6 (only unreachability on :8095 passes)
# AND ref-solution (post-ref-solution state) scores 6/6.
# NOTE: When Wave 3 (07.1-05) rewrites this grader to gate reachability on candidate-authored NP,
# the post-setup score should drop to 0. Update fixtures via --regen at that time.

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="services-networking"
slug="06-netpol-endport"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# ----- empty submission test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-services-networking-06"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 1/6"

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
expected_ref_score="SCORE: 6/6"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  exit 1
fi
