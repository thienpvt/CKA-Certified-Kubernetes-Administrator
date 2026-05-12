#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q07-kubelet-flags"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
