#!/bin/bash
# troubleshooting/06-broken-kubelet/reset.sh
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q06-kubelet-flags"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Phase 07.1 AUDIT-01: per-question tmp cleanup (lint requires slug-named path).
rm -rf /tmp/cka-sim/06-broken-kubelet/
