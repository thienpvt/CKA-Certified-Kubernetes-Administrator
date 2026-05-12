#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

sandbox="/tmp/q04-debug-node"
worker=$(cat "$sandbox/worker.txt" 2>/dev/null || echo "")

if [[ -z "$worker" ]]; then
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
  CKA_SIM_GRADE_FAILS+=("worker hostname sentinel missing — reset may have run")
  err "worker hostname sentinel missing — reset may have run"
fi

expected=""
if [[ -n "$worker" ]]; then
  expected=$(kubectl get node "$worker" -o jsonpath='{.status.nodeInfo.kernelVersion}' 2>/dev/null || echo "")
fi
actual=$(cat "$sandbox/answer.txt" 2>/dev/null || echo "")

debug_pods_running=$(kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source' --field-selector=status.phase=Running -o name 2>/dev/null || echo "")
debug_pods_succeeded=$(kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source' --field-selector=status.phase=Succeeded -o name 2>/dev/null || echo "")
debug_pods_failed=$(kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source' --field-selector=status.phase=Failed -o name 2>/dev/null || echo "")
debug_evidence="${debug_pods_running}${debug_pods_succeeded}${debug_pods_failed}"
ephemeral=$(kubectl get pods -n "$CKA_SIM_LAB_NS" -o jsonpath='{.items[*].metadata.annotations.kubectl\.kubernetes\.io/debug-container}' 2>/dev/null || echo "")

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$actual" && -n "$expected" && "$actual" == "$expected" && -n "$debug_evidence" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("answer.txt matches node kernelVersion (discovered via kubectl debug node)")
  ok "answer.txt matches node kernelVersion (discovered via kubectl debug node)"
else
  CKA_SIM_GRADE_FAILS+=("answer.txt must match node kernelVersion and kubectl debug node evidence must exist")
  err "answer.txt must match node kernelVersion and kubectl debug node evidence must exist"
  if [[ -n "$actual" && -n "$expected" && "$actual" == "$expected" && -z "$debug_evidence" ]]; then
    cka_sim::grade::record_trap debug-ephemeral-vs-node-confusion
  fi
  if [[ "$actual" != "$expected" && -n "$ephemeral" && -z "$debug_evidence" ]]; then
    cka_sim::grade::record_trap debug-node-missing-chroot-host
  fi
fi

if [[ -n "$debug_pods_running" ]]; then
  cka_sim::grade::record_trap debug-pod-leaked-not-cleaned
fi

cka_sim::grade::emit_result
