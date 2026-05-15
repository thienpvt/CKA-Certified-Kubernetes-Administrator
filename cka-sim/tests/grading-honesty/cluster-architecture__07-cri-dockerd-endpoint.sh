#!/bin/bash
# Phase 07.1 grading-honesty regression: cluster-architecture/07-cri-dockerd-endpoint
#
# AUDIT-ESCAPE (D-22 file-baseline gap): candidate work is filesystem-only —
# edits /tmp/q07-kubelet-flags/kubeadm-flags.env. lib/baseline.sh tracks K8s API
# resources only. Phase 07.1 demotes "file exists" to weight=0; only the CRI
# endpoint content check (weight=1) scores.
#
# Setup state: broken kubeadm-flags.env with --container-runtime=remote → 0/1 + traps.
# Ref-solution: correct --container-runtime-endpoint=unix:///run/cri-dockerd.sock → 1/1.

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="cluster-architecture"
slug="07-cri-dockerd-endpoint"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"
sandbox="/tmp/q07-kubelet-flags"

# Pre-clean
rm -rf "$sandbox"
mkdir -p "$sandbox"

# ----- empty submission test (setup state: broken flags file) -----
printf 'KUBELET_KUBEADM_ARGS="--container-runtime=remote --pod-infra-container-image=registry.k8s.io/pause:3.10"\n' > "$sandbox/kubeadm-flags.env"
: > "$sandbox/kubelet.conf"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-cluster-architecture-07"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/1"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score [audit-escape: file-exists demoted to weight=0]"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  echo "$out" | tail -20 >&2
  rm -rf "$sandbox"
  exit 1
fi

# Verify trap fires on broken state
if echo "$out" | grep -q 'Trap.*removed-container-runtime-flag'; then
  ok "trap removed-container-runtime-flag fires on setup state"
fi

# ----- ref-solution test (correct CRI endpoint) -----
cat > "$sandbox/kubeadm-flags.env" <<'EOF'
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/cri-dockerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10"
EOF
: > "$sandbox/kubelet.conf"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 1/1"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  echo "$out" | tail -20 >&2
  rm -rf "$sandbox"
  exit 1
fi

rm -rf "$sandbox"
