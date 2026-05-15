#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q03-kubeadm-upgrade"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
# Phase 07.1 AUDIT-01 — purge canonical sandbox path
rm -rf /tmp/cka-sim/03-kubeadm-upgrade/
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Remove per-question baseline dir
rm -rf "/tmp/cka-sim/cluster-architecture-kubeadm-upgrade/"

exit 0
