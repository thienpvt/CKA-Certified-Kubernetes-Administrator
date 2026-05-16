#!/bin/bash
# Phase 07.1 grading-honesty regression: troubleshooting/04-debug-node
# AUDIT-ESCAPE: file-edit baseline gap. answer.txt + debug-pod evidence is candidate-driven by design.
# Asserts empty submission (post-setup state) scores 0/1 (answer.txt empty + no debug pod)
# AND ref-solution (post-ref-solution state) scores 1/1 (answer.txt matches kernelVersion + debug pod exists).

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="troubleshooting"
slug="04-debug-node"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# Setup: write the candidate sandbox (grade.sh reads from filesystem).
sandbox="/tmp/q04-debug-node"
mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"
printf 'worker-1\n' > "$sandbox/worker.txt"

# ----- empty submission test -----
# Empty submission: answer.txt empty, no kubectl debug evidence.
: > "$sandbox/answer.txt"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-troubleshooting-04"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/1"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# ----- ref-solution test -----
# Ref-solution: answer.txt matches kernelVersion, debug pod exists (mocked in .fixtures.json).
printf '5.15.0-92-generic\n' > "$sandbox/answer.txt"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 1/1"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# Cleanup
rm -rf "$sandbox"
