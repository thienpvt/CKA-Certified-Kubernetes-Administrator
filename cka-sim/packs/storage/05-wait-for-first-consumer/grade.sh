#!/bin/bash
# storage/05-wait-for-first-consumer/grade.sh — asserts Pod ready + PVC bound + claim ref;
# records WFFC trap if PVC still Pending without a consumer, records default-sa-used if the
# candidate's Pod skipped ServiceAccount hygiene.
# GRADE-02: behavioural kubectl calls only (no `kubectl get | grep`).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Best-effort wait: Pod may still be Pending-scheduled for a few seconds after ref-solution.sh
# returns (WFFC triggers the first-consumer bind as soon as the pod is scheduled).
# 2>/dev/null suppresses kubectl errors (e.g., pod not yet created) — a miss is counted by the
# assertions below, not here. `|| true` keeps grade.sh flowing even under set -uo pipefail.
kubectl wait --for=condition=Ready pod/q05-consumer -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true

# Assertion 1: candidate created Pod q05-consumer and it is Ready.
cka_sim::grade::assert_pod_ready "$CKA_SIM_LAB_NS" q05-consumer

# Assertion 2: PVC q05-claim is now Bound (WFFC resolved because pod was scheduled).
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" q05-claim

# Assertion 3: Pod mounts q05-claim via the first volume's persistentVolumeClaim.claimName.
cka_sim::grade::assert_field_eq pod q05-consumer \
  '{.spec.volumes[0].persistentVolumeClaim.claimName}' \
  'q05-claim' \
  -n "$CKA_SIM_LAB_NS"

# Trap: PVC still Pending + no consumer Pod yet -> primary WFFC trap.
pvc_phase=$(kubectl get pvc q05-claim -n "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
pod_exists=$(kubectl get pod q05-consumer -n "$CKA_SIM_LAB_NS" -o name 2>/dev/null || echo "")
if [[ "$pvc_phase" == "Pending" && -z "$pod_exists" ]]; then
  cka_sim::grade::record_trap pvc-pending-wffc-unscheduled-consumer
fi

# Trap: candidate's Pod uses the default ServiceAccount (auto-mounted token is a security smell).
if [[ -n "$pod_exists" ]]; then
  tid=$(cka_sim::trap::detect_default_sa_used "$CKA_SIM_LAB_NS" q05-consumer)
  [[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
fi

# Finalize — prints SCORE + Trap N: lines to stdout.
cka_sim::grade::emit_result
