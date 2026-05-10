#!/bin/bash
# storage/03-access-modes-reclaim/grade.sh — behavioural grader (GRADE-02).
# Asserts: both PVCs Bound + q03-retain-pv reclaim=Delete + q03-delete-pv accessModes[0]=ReadWriteMany.
# Records traps: pv-accessmodes-mismatch (RWX PVC still Pending AND no PV advertises RWX)
# and reclaim-policy-delete-data-loss (q03-retain-pv still Retain).
# No mutating verbs; no `kubectl get | grep`.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Give the binder a moment to react to any candidate patches before asserting.
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/q03-rwo-pvc -n "$CKA_SIM_LAB_NS" --timeout=30s >/dev/null 2>&1 || true
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/q03-rwx-pvc -n "$CKA_SIM_LAB_NS" --timeout=60s >/dev/null 2>&1 || true

# Assertions (4, each weight 1).
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" q03-rwo-pvc
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" q03-rwx-pvc
cka_sim::grade::assert_field_eq pv q03-retain-pv '{.spec.persistentVolumeReclaimPolicy}' 'Delete'
cka_sim::grade::assert_field_eq pv q03-delete-pv '{.spec.accessModes[0]}' 'ReadWriteMany'

# Trap: RWX PVC still Pending AND no PV advertises RWX -> pv-accessmodes-mismatch.
phase=$(kubectl get pvc q03-rwx-pvc -n "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
rwx_names=$(kubectl get pv -o jsonpath='{.items[?(@.spec.accessModes[0]=="ReadWriteMany")].metadata.name}' 2>/dev/null || echo "")
rwx_count=$(printf '%s' "$rwx_names" | wc -w | tr -d ' ')
if [[ "$phase" == "Pending" && "${rwx_count:-0}" == "0" ]]; then
  cka_sim::grade::record_trap pv-accessmodes-mismatch
  cka_sim::grade::record_trap pvc-accessmode-rwx-on-rwo-sc
fi

# Trap: q03-retain-pv still Retain -> reclaim-policy-delete-data-loss (inverse framing:
# the lesson is that Retain is the safe default; deleting data accidentally via Delete
# reclaim is the catalogued risk. This trap fires so the candidate sees the warning
# when they leave the PV on Retain against the business-rule change).
retain=$(kubectl get pv q03-retain-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null || echo "")
if [[ "$retain" == "Retain" ]]; then
  cka_sim::grade::record_trap reclaim-policy-delete-data-loss
fi

# Finalize — prints SCORE + Trap N: lines to stdout.
cka_sim::grade::emit_result
