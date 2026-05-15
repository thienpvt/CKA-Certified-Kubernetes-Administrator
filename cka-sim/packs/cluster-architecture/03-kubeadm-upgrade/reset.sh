#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q03-kubeadm-upgrade"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Remove per-question baseline dir
rm -rf "/tmp/cka-sim/cluster-architecture-kubeadm-upgrade/"

exit 0
