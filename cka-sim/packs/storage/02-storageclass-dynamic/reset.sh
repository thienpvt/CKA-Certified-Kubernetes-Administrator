#!/bin/bash
# storage/02-storageclass-dynamic/reset.sh — async ns delete + cluster-scoped SC cleanup.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (runner owns cleanup; TRIP-03 pattern).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped — drop the StorageClass the candidate (or ref-solution) created.
kubectl delete storageclass fast-ssd --ignore-not-found

exit 0
