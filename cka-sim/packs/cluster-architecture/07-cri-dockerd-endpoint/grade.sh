#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

sandbox="/tmp/q07-kubelet-flags"
flags="$sandbox/kubeadm-flags.env"
kubeconfig="$sandbox/kubelet.conf"
removed_flag="container-runtime""=remote"

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -s "$flags" ]]; then CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 )); ok "kubeadm-flags.env exists"; else CKA_SIM_GRADE_FAILS+=("kubeadm-flags.env missing"); err "kubeadm-flags.env missing"; fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if grep -qE 'KUBELET_KUBEADM_ARGS=.*--container-runtime-endpoint=unix:///run/cri-dockerd\.sock' "$flags" 2>/dev/null; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "correct CRI endpoint present"
else
  CKA_SIM_GRADE_FAILS+=("correct CRI endpoint missing")
  err "correct CRI endpoint missing"
fi

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
