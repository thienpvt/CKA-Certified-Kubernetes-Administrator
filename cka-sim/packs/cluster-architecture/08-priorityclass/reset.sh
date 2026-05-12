#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q08-priorityclass"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
kubectl delete priorityclass q08-critical q08-batch --ignore-not-found
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
