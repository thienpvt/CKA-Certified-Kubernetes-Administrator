#!/bin/bash
# storage/01-pvc-binding/reset.sh — async ns delete + cluster-scoped PV cleanup.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete
# 1a. Phase 10 BUG-H01 — explicit Pod cleanup (Pod is in $CKA_SIM_LAB_NS but is named so we
#     delete it directly to make reset.sh self-documenting about the resources setup creates).
kubectl delete pod q01-app-consumer -n "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped (q<NN>- prefix per TRIP-03)
kubectl delete pv q01-app-pv --ignore-not-found

# 3. Phase 07.1 AUDIT-01: clear per-question tmp dir (baseline + capture artefacts).
rm -rf /tmp/cka-sim/01-pvc-binding/

exit 0
