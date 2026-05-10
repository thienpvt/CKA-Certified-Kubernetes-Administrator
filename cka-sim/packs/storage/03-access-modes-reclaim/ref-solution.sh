#!/bin/bash
# storage/03-access-modes-reclaim/ref-solution.sh — patches PVs in place (no delete-recreate)
# to satisfy both fixes: (a) q03-delete-pv accessModes -> [ReadWriteMany] so q03-rwx-pvc binds,
# (b) q03-retain-pv persistentVolumeReclaimPolicy -> Delete per the business-rule change.
# Invoked by GRADE-06 round-trip: bash setup.sh && bash ref-solution.sh && bash grade.sh -> 4/4 + 0 traps.
# NOT exposed to candidates during drills.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Fix 1: offer RWX on q03-delete-pv so q03-rwx-pvc can bind.
kubectl patch pv q03-delete-pv --type=json -p='[
  {"op": "replace", "path": "/spec/accessModes", "value": ["ReadWriteMany"]}
]'

# Fix 2: flip q03-retain-pv reclaim policy to Delete.
kubectl patch pv q03-retain-pv --type=json -p='[
  {"op": "replace", "path": "/spec/persistentVolumeReclaimPolicy", "value": "Delete"}
]'

# Wait for binder to catch up before grader runs.
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/q03-rwx-pvc -n "$CKA_SIM_LAB_NS" --timeout=60s
