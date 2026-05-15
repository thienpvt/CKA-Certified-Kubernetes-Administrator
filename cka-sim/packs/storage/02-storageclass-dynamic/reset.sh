#!/bin/bash
# storage/02-storageclass-dynamic/reset.sh — async ns delete + cluster-scoped SC cleanup.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (runner owns cleanup; TRIP-03 pattern).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped — drop the StorageClass the candidate (or ref-solution) created,
#    but ONLY if it carries our ownership label. WR-06 (04-REVIEW.md): fast-ssd is
#    a generic name; an unrelated SC with the same name (from another candidate or
#    concurrent lab) must not be stomped by this reset. ref-solution.sh labels the
#    SC it creates; a candidate who named their own SC fast-ssd without the label
#    retains it.
sc_owned=$(kubectl get sc fast-ssd -l cka-sim/uses=storage-storageclass-dynamic -o name 2>/dev/null || true)
if [[ -n "$sc_owned" ]]; then
  kubectl delete storageclass fast-ssd --ignore-not-found
fi

# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/storage-storageclass-dynamic/"

exit 0
