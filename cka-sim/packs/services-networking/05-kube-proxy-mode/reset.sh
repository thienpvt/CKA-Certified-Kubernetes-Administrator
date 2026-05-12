#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Sentinel-guarded sandbox cleanup — only remove if our sentinel exists
if [[ -f /tmp/q05-kube-proxy/.cka-sim-sentinel ]]; then
  rm -rf /tmp/q05-kube-proxy
fi

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
exit 0
