#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q04-debug-node"

kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source' -o name 2>/dev/null | xargs -r kubectl delete --ignore-not-found 2>/dev/null || true

if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/troubleshooting-debug-node/"

exit 0
