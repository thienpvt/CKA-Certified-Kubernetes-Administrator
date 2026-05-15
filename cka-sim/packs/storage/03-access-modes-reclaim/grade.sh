#!/bin/bash
# Phase 07.1 AUDIT-01 — assert_pvc_bound q03-rwo-pvc leaked at empty submission
#   (setup binds it immediately) -> replaced with assert_changed_since_setup pv q03-retain-pv
#   to gate on actual candidate modification of the PV (the candidate's first deliverable).
# storage/03-access-modes-reclaim/grade.sh — behavioural grader (GRADE-02).
# Asserts: q03-retain-pv candidate-modified + q03-rwx-pvc Bound + q03-retain-pv reclaim=Delete + q03-delete-pv accessModes[0]=ReadWriteMany.
# Records traps: pv-accessmodes-mismatch (RWX PVC still Pending AND no PV advertises RWX)
# and reclaim-policy-retain-when-delete-required (q03-retain-pv still Retain — the
# business-rule direction; CR-02 realignment vs the old reclaim-policy-delete-data-loss
# entry whose canonical message describes the inverse Delete direction).
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
# Assertion 1 (Phase 07.1 AUDIT-01): q03-retain-pv must be candidate-modified.
#   Replaces the leaky `assert_pvc_bound q03-rwo-pvc` (setup binds q03-rwo-pvc to
#   q03-retain-pv immediately because both are RWO + storageClassName=manual + 1Gi).
#   The candidate's primary deliverable for q03-retain-pv is flipping reclaimPolicy
#   to Delete; this gate verifies the resource was actually touched.
cka_sim::grade::assert_changed_since_setup pv q03-retain-pv
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" q03-rwx-pvc
cka_sim::grade::assert_field_eq pv q03-retain-pv '{.spec.persistentVolumeReclaimPolicy}' 'Delete'
cka_sim::grade::assert_field_eq pv q03-delete-pv '{.spec.accessModes[0]}' 'ReadWriteMany'

# Trap: RWX PVC still Pending AND no PV advertises RWX -> pv-accessmodes-mismatch.
# WR-05 (04-REVIEW.md): previously also recorded pvc-accessmode-rwx-on-rwo-sc on
# the same condition, but that catalog entry describes a StorageClass-level RWO
# limitation and this question uses manual PV binding (storageClassName=manual),
# not a dynamic RWO-only SC. The two traps have different root causes; collapsing
# them onto one condition misled the learner.
# WR-04 (04-REVIEW.md): scope the RWX scan to THIS question's PVs via the
# cka-sim/question-id label so a RWX PV left over from another lab on the same
# cluster cannot suppress the trap with a false negative.
phase=$(kubectl get pvc q03-rwx-pvc -n "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
rwx_names=$(kubectl get pv -l cka-sim/question-id=storage-access-modes-reclaim \
  -o jsonpath='{.items[?(@.spec.accessModes[0]=="ReadWriteMany")].metadata.name}' 2>/dev/null || echo "")
rwx_count=$(printf '%s' "$rwx_names" | wc -w | tr -d ' ')
if [[ "$phase" == "Pending" && "${rwx_count:-0}" == "0" ]]; then
  cka_sim::grade::record_trap pv-accessmodes-mismatch
fi

# Trap: q03-retain-pv still Retain -> reclaim-policy-retain-when-delete-required.
# The question's business rule says the PV must now delete its storage with the PVC;
# leaving it on Retain orphans the volume. The catalog entry's wording matches the
# detected condition directly (CR-02 fix: previously this path recorded
# reclaim-policy-delete-data-loss, whose canonical message describes the Delete
# direction and contradicted what the grader detected).
retain=$(kubectl get pv q03-retain-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null || echo "")
if [[ "$retain" == "Retain" ]]; then
  cka_sim::grade::record_trap reclaim-policy-retain-when-delete-required
fi

# Finalize — prints SCORE + Trap N: lines to stdout.
cka_sim::grade::emit_result
