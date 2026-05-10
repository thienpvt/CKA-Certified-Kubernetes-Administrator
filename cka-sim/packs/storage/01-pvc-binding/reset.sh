#!/bin/bash
# storage/01-pvc-binding/reset.sh — async ns delete + cluster-scoped PV cleanup.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped (q<NN>- prefix per TRIP-03)
kubectl delete pv q01-app-pv --ignore-not-found

exit 0
