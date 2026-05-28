#!/bin/bash
# Phase 07.1 grading-honesty regression: services-networking/06-netpol-endport
# Phase 13 BUG-M04 reshape — grader is now CNI-enforcement-aware:
#   sentinel=true   → 4 structural + 4 reachability = max 8
#   sentinel=false  → 4 structural only             = max 4
#   sentinel missing→ 4 structural only             = max 4
# Unit tests run with no sentinel file present → exercises the missing-sentinel
# branch → max 4. Exec-line fixture entries below are dead code on this branch
# but kept so the test stays accurate if someone hand-injects the sentinel.
# Empty submission: 0/4. Ref-solution: 4/4.
# NOTE: The 6-port enforcing-CNI flow (max 8) is exercised by the live UAT
# driver `cka-sim/scripts/uat-phase13.sh` instead of this unit fixture.

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="services-networking"
slug="06-netpol-endport"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

rm -rf /tmp/q06-netpol-endport

# ----- empty submission test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-services-networking-06"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/4"

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
expected_ref_score="SCORE: 4/4"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  exit 1
fi
