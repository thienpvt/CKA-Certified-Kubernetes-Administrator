#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q08-priorityclass"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
# Phase 07.1 AUDIT-01 — purge canonical sandbox path
rm -rf /tmp/cka-sim/08-priorityclass/
kubectl delete priorityclass q08-critical q08-batch --ignore-not-found
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Remove per-question baseline dir
rm -rf "/tmp/cka-sim/cluster-architecture-priorityclass/"

exit 0
