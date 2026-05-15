#!/bin/bash
# Phase 07.1 grading-honesty regression: cluster-architecture/04-pss-enforce
# Asserts empty submission (post-setup state) scores 4/5 (only readyReplicas=0 fails)
# AND ref-solution (post-ref-solution state) scores 5/5.
# NOTE: When Wave 3 (07.1-06) rewrites this grader to use assert_resource_candidate_authored
# for the Pod, the post-setup score should drop to 0. Update fixtures via --regen at that time.

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="cluster-architecture"
slug="04-pss-enforce"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# Setup: write admission log fixture (grade.sh reads from filesystem, not kubectl)
sandbox="/tmp/q04-pss-enforce"
mkdir -p "$sandbox"
printf 'violates PodSecurity "restricted:v1.35": ...' > "$sandbox/violator-admission.log"

# ----- empty submission test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-cluster-architecture-04"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 4/5"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# ----- ref-solution test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 5/5"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# Cleanup
rm -rf "$sandbox"
