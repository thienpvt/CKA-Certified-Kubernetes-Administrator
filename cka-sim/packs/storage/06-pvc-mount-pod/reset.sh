#!/bin/bash
# storage/06-pvc-mount-pod/reset.sh — async ns delete + cluster-scoped PV cleanup.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (runner owns any sync waits per D-09).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped PV (q<NN>- prefix per TRIP-03).
kubectl delete pv q06-data-pv --ignore-not-found

# 3. Phase 07.1 AUDIT-01: clear per-question tmp dir (baseline + capture artefacts).
rm -rf /tmp/cka-sim/06-pvc-mount-pod/

exit 0
