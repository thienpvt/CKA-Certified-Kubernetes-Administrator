#!/bin/bash
# troubleshooting/04-debug-node/reset.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q04-debug-node"

kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source' -o name 2>/dev/null | xargs -r kubectl delete --ignore-not-found 2>/dev/null || true

if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Phase 07.1 AUDIT-01: per-question tmp cleanup (lint requires slug-named path).
rm -rf /tmp/cka-sim/04-debug-node/

exit 0
