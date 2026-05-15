#!/bin/bash
# workloads-scheduling/08-nodeselector-affinity-taints/reset.sh
# Cluster-scoped cleanup: removes both the gpu=true label AND the
# gpu=true:NoSchedule taint from the worker that setup.sh selected, so
# later questions do not see unexpected scheduler behaviour. Discovery
# idiom is identical to setup.sh (same selector, same jsonpath) so the
# same worker is selected within one drill invocation.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

target_node=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  --no-headers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "${target_node}" ]]; then
  # Untaint the worker (trailing dash on key = remove).
  kubectl taint nodes "${target_node}" gpu- 2>/dev/null || true
  # Unlabel the worker (trailing dash on key = remove).
  # IN-03 (04-REVIEW.md): --overwrite is only meaningful when SETTING a label;
  # for 'key-' removal syntax the flag is a no-op and newer kubectl warns on it.
  kubectl label nodes "${target_node}" gpu- 2>/dev/null || true
fi

# Phase 07.1 AUDIT-01: clean per-question tmp scratch (baseline + transient artefacts).
rm -rf /tmp/cka-sim/08-nodeselector-affinity-taints/

exit 0
