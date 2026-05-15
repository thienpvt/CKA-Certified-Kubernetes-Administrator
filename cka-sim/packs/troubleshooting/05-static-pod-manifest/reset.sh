#!/bin/bash
# troubleshooting/05-static-pod-manifest/reset.sh
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q05-staticpod"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Phase 07.1 AUDIT-01: per-question tmp cleanup (lint requires slug-named path).
rm -rf /tmp/cka-sim/05-static-pod-manifest/
