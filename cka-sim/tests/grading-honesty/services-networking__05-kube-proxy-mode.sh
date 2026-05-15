#!/bin/bash
# Phase 07.1 grading-honesty regression: services-networking/05-kube-proxy-mode
# Asserts empty submission scores 0/3 (sandbox file unchanged from seeded 'ipvs';
# candidate-write gate fails, downstream assertions skipped).
# Ref-solution scores 3/3 after candidate writes 'iptables' (matching live mode).

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="services-networking"
slug="05-kube-proxy-mode"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

sandbox="/tmp/q05-kube-proxy"
mkdir -p "$sandbox"

cleanup_sandbox() {
  rm -rf "$sandbox"
}
trap cleanup_sandbox EXIT

# ----- empty submission test -----
# Setup: seed file = 'ipvs', reported file = 'ipvs' (candidate has not written)
echo "ipvs" > "$sandbox/.setup-seeded-mode"
echo "ipvs" > "$sandbox/reported-mode.txt"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-services-networking-05"

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
# Setup: seed file = 'ipvs' (unchanged), reported file = 'iptables' (candidate overwrote)
echo "ipvs" > "$sandbox/.setup-seeded-mode"
echo "iptables" > "$sandbox/reported-mode.txt"

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
