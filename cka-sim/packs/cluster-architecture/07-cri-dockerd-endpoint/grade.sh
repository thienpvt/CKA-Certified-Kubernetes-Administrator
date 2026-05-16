#!/bin/bash
# Phase 07.1 AUDIT-01 — distinguish setup-state from candidate work.
# Phase 07.1 D-22 audit-escape: file-baseline gap.
#
# cluster-architecture/07-cri-dockerd-endpoint/grade.sh
#
# Ownership analysis:
#   - setup.sh writes /tmp/q07-kubelet-flags/kubeadm-flags.env with the broken
#     "--container-runtime=remote" deprecated flag (Plan 01 tagged setup-allowed)
#     and an empty kubelet.conf.
#   - Candidate work: rewrite kubeadm-flags.env to use
#     --container-runtime-endpoint=unix:///run/cri-dockerd.sock.
#   - "kubeadm-flags.env exists" passes on setup ownership → weight=0.
#   - CRI-endpoint content check is candidate-work → weight=1.
#   - Trap detectors operate on file text content; they fire on the broken
#     setup state without an ownership gate (desired — they're traps, not
#     positive scoring).
#   - File-baseline gap: lib/baseline.sh (D-03) tracks K8s API resources only;
#     v1.x scope expansion needed for file-mtime + sha256 baseline support.
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

sandbox="/tmp/q07-kubelet-flags"
flags="$sandbox/kubeadm-flags.env"
kubeconfig="$sandbox/kubelet.conf"
removed_flag="container-runtime""=remote"

# Setup-state assertion (weight=0): kubeadm-flags.env is written by setup.sh.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 0 ))
if [[ -s "$flags" ]]; then ok "kubeadm-flags.env exists [weight=0 setup-state]"; else err "kubeadm-flags.env missing [weight=0 setup-state]"; fi

# Candidate-work assertion (weight=1): correct CRI endpoint must be present.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if grep -qE 'KUBELET_KUBEADM_ARGS=.*--container-runtime-endpoint=unix:///run/cri-dockerd\.sock' "$flags" 2>/dev/null; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "correct CRI endpoint present"
else
  CKA_SIM_GRADE_FAILS+=("correct CRI endpoint missing")
  err "correct CRI endpoint missing"
fi

# Trap detectors fire on broken-text content (Plan 01 tagged setup-allowed):
if grep -q "$removed_flag" "$flags" 2>/dev/null; then
  cka_sim::grade::record_trap removed-container-runtime-flag
fi

if grep -q 'container-runtime-endpoint' "$kubeconfig" 2>/dev/null; then
  cka_sim::grade::record_trap kubelet-runtime-flag-in-kubeconfig
fi

endpoint=$(awk -F'container-runtime-endpoint=' '/container-runtime-endpoint=/{print $2}' "$flags" 2>/dev/null | awk '{print $1}' | tr -d '"' | head -1)
if [[ -n "$endpoint" && "$endpoint" != unix://* ]]; then
  cka_sim::grade::record_trap cri-endpoint-unix-prefix-missing
fi

cka_sim::grade::emit_result
