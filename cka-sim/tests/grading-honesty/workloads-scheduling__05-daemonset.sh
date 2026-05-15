#!/bin/bash
# Phase 07.1 grading-honesty regression: workloads-scheduling/05-daemonset
# Asserts empty submission (post-setup, no DaemonSet) scores 0/4 AND ref-solution scores 4/4.
# RESEARCH Q5 prediction: LOW (candidate creates DS from scratch).
# Audit verdict: assert_resource_exists daemonset -> assert_resource_candidate_authored (stricter).
# Also gated the daemonset-missing-control-plane-toleration trap on DS existence so empty
# submission doesn't fire a spurious trap.
# Test fixture: 2 nodes in stub stdout produces wc -l = 1 (bash $(...) strips trailing newline).

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="workloads-scheduling"
slug="05-daemonset"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# ----- empty submission test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-workloads-scheduling-05"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/4"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  exit 1
fi

# Assert no traps on empty submission (CP-toleration trap is gated on DS existence).
trap_count=$(echo "$out" | grep -cE '^Trap [0-9]+:' || true)
if (( trap_count == 0 )); then
  ok "empty submission $test_id: 0 traps recorded"
else
  err "empty submission $test_id: expected 0 traps, got $trap_count"
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
