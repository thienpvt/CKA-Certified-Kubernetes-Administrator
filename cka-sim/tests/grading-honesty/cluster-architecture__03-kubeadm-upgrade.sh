#!/bin/bash
# Phase 07.1 grading-honesty regression: cluster-architecture/03-kubeadm-upgrade
# Pure filesystem grader (no kubectl calls). Sandbox files are set up by the
# test harness to simulate post-setup (empty files) and post-ref-solution
# (filled content) states.
#
# Empty submission scores 0/5 + records the kubeadm-upgrade-skip-plan trap (deduped to one entry).
# Ref-solution scores 5/5 with no traps.

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="cluster-architecture"
slug="03-kubeadm-upgrade"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"
sandbox="/tmp/q03-kubeadm-upgrade"

# Pre-clean
rm -rf "$sandbox"
mkdir -p "$sandbox"

# ----- empty submission test (setup state: empty files) -----
: > "$sandbox/planned-upgrade.txt"
: > "$sandbox/apply-script.sh"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-cluster-architecture-03"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/5"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  echo "$out" | tail -20 >&2
  rm -rf "$sandbox"
  exit 1
fi

# ----- ref-solution test (sandbox files filled with content) -----
cat > "$sandbox/planned-upgrade.txt" <<'EOF'
# Upgrade plan
Target version: v1.35.0
Run kubeadm upgrade plan, confirm v1.35.0, then apply.
EOF
cat > "$sandbox/apply-script.sh" <<'EOF'
#!/bin/bash
kubeadm upgrade plan
kubeadm upgrade apply v1.35.0
EOF

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 5/5"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  echo "$out" | tail -20 >&2
  rm -rf "$sandbox"
  exit 1
fi

rm -rf "$sandbox"
