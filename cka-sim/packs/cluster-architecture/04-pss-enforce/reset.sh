#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q04-pss-enforce"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
rm -rf /tmp/cka-sim/04-pss-enforce/
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Remove per-question baseline dir
rm -rf "/tmp/cka-sim/cluster-architecture-pss-enforce/"

exit 0
