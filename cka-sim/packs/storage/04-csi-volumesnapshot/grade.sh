#!/bin/bash
# storage/04-csi-volumesnapshot/grade.sh
# Read-only grader (no mutating verbs): asserts a VolumeSnapshot exists,
# sources the seeded PVC `app-data`, and has `.status.readyToUse == true`.
# Uses `kubectl wait --for=jsonpath` for the behavioural GRADE-02 assertion.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Give the snapshot up to 90s to settle (GRADE-02 behavioural wait).
# `kubectl wait --for=jsonpath` is read-only; passes the mutating-verb lint.
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/q04-app-snapshot -n "$CKA_SIM_LAB_NS" --timeout=90s 2>/dev/null || true

# Assertion 1: the VolumeSnapshot exists.
cka_sim::grade::assert_resource_exists volumesnapshot q04-app-snapshot -n "$CKA_SIM_LAB_NS"

# Assertion 2: its source is the seeded PVC `app-data`.
cka_sim::grade::assert_field_eq volumesnapshot q04-app-snapshot \
  '{.spec.source.persistentVolumeClaimName}' 'app-data' -n "$CKA_SIM_LAB_NS"

# Assertion 3: behavioural — snapshot is actually ready to use.
cka_sim::grade::assert_field_eq volumesnapshot q04-app-snapshot \
  '{.status.readyToUse}' 'true' -n "$CKA_SIM_LAB_NS"

# Trap detection: VolumeSnapshotClass driver points at something other than the
# installed hostpath driver AND the snapshot never became ready -> wrong driver.
driver=$(kubectl get volumesnapshotclass csi-hostpath-snapshotclass \
  -o jsonpath='{.driver}' 2>/dev/null || echo "")
ready=$(kubectl get volumesnapshot q04-app-snapshot -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.status.readyToUse}' 2>/dev/null || echo "")
if [[ -n "$driver" && "$driver" != "hostpath.csi.k8s.io" && "$ready" != "true" ]]; then
  cka_sim::grade::record_trap csi-snapshot-wrong-driver
fi

# Trap detection: PVC `app-data` still Pending AND writer pod never scheduled —
# classic WaitForFirstConsumer failure (candidate deleted the writer pod).
pvc_phase=$(kubectl get pvc app-data -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
writer_phase=$(kubectl get pod q04-writer -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
if [[ "$pvc_phase" == "Pending" && "$writer_phase" == "Pending" ]]; then
  cka_sim::grade::record_trap pvc-pending-wffc-unscheduled-consumer
fi

# Trap detection: PVC storageClassName points at something other than the
# seeded csi-hostpath-sc — candidate hand-edited the claim.
pvc_sc=$(kubectl get pvc app-data -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
if [[ -n "$pvc_sc" && "$pvc_sc" != "csi-hostpath-sc" ]]; then
  cka_sim::grade::record_trap pvc-wrong-storageclass
fi

cka_sim::grade::emit_result
