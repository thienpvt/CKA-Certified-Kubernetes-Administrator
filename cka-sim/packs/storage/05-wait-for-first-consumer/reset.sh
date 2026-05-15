#!/bin/bash
# storage/05-wait-for-first-consumer/reset.sh — async ns delete + cluster-scoped cleanup.
# D-09: runner owns ns cleanup; this is the question-level teardown that removes cluster-
# scoped artefacts (PV + SC) which don't get swept by the ns deletion.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (PVC + Pod go with the ns).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped artefacts (q<NN>- prefix per TRIP-03).
kubectl delete pv q05-wffc-pv --ignore-not-found
kubectl delete storageclass q05-wffc --ignore-not-found

# 3. Phase 07.1 AUDIT-01: clear per-question tmp dir (baseline + capture artefacts).
rm -rf /tmp/cka-sim/05-wait-for-first-consumer/

exit 0
