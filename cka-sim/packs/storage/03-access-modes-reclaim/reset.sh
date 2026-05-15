#!/bin/bash
# storage/03-access-modes-reclaim/reset.sh — async ns delete + cluster-scoped PV cleanup.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (runner owns authoritative cleanup via D-09).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped PVs (q03- prefix per TRIP-03).
kubectl delete pv q03-retain-pv q03-delete-pv --ignore-not-found

# 3. Phase 07.1 AUDIT-01: clear per-question tmp dir (baseline + capture artefacts).
rm -rf /tmp/cka-sim/03-access-modes-reclaim/

exit 0
