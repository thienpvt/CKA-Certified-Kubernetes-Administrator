#!/bin/bash
# Phase 07.1 grading-honesty regression: troubleshooting/06-broken-kubelet
# AUDIT-ESCAPE + partial demote: file-existence demoted to weight=0; bash-parseable + correct-CRI-endpoint require candidate work.
# Asserts empty submission (post-setup state) scores 0/2 (broken quoting + wrong CRI endpoint)
# AND ref-solution (post-ref-solution state) scores 2/2 (parseable + correct CRI endpoint).

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="troubleshooting"
slug="06-broken-kubelet"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# Setup: write the candidate sandbox.
sandbox="/tmp/q06-kubelet-flags"
mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"

# ----- empty submission test -----
# Empty submission: write the broken flag file (malformed quoting + wrong CRI endpoint).
printf 'KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=/run/cri-dockerd.sock --pod-"infra-container-image=registry.k8s.io/pause:3.10"\n' > "$sandbox/kubeadm-flags.env"
: > "$sandbox/kubelet.conf"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-troubleshooting-06"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/2"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# ----- ref-solution test -----
# Ref-solution: write the fixed flag file.
cat > "$sandbox/kubeadm-flags.env" <<'EOF'
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/cri-dockerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10"
EOF
: > "$sandbox/kubelet.conf"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 2/2"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# Cleanup
rm -rf "$sandbox"
