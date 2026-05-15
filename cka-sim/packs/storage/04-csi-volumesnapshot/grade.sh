#!/bin/bash
# Phase 07.1 AUDIT-01 — no leak found (all asserted resources are candidate-authored)
# storage/04-csi-volumesnapshot/grade.sh
# Grades VolumeSnapshotClass + VolumeSnapshot schema authoring (CG-01).
#
# Why no readyToUse check:
#   rancher.io/local-path does NOT implement CSI snapshots, so a
#   VolumeSnapshot against it will never transition to readyToUse=true.
#   The question is explicit in question.md that this is an API-schema
#   exercise (the CKA exam tests conceptual snapshot knowledge, not a
#   working backup). Grader asserts schema correctness + that the
#   candidate correctly identifies the installed provisioner's driver.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertion 1: candidate created VolumeSnapshotClass named q04-snapclass.
cka_sim::grade::assert_resource_exists volumesnapshotclass q04-snapclass

# Assertion 2: the VolumeSnapshotClass driver field references the
# local-path provisioner installed on the candidate's cluster.
cka_sim::grade::assert_field_eq volumesnapshotclass q04-snapclass \
  '{.driver}' 'rancher.io/local-path'

# Assertion 3: candidate created VolumeSnapshot q04-snapshot in the lab ns.
cka_sim::grade::assert_resource_exists volumesnapshot q04-snapshot -n "$CKA_SIM_LAB_NS"

# Assertion 4: VolumeSnapshot.spec.source.persistentVolumeClaimName == 'app-data'.
cka_sim::grade::assert_field_eq volumesnapshot q04-snapshot \
  '{.spec.source.persistentVolumeClaimName}' 'app-data' \
  -n "$CKA_SIM_LAB_NS"

# Trap detector: csi-snapshot-wrong-driver -- if the VSC driver points at a
# driver that is neither 'rancher.io/local-path' nor a CSIDriver registered
# on this cluster, the candidate named a driver that cannot serve snapshots.
if kubectl get volumesnapshotclass q04-snapclass >/dev/null 2>&1; then
  vsc_driver=$(kubectl get volumesnapshotclass q04-snapclass -o jsonpath='{.driver}' 2>/dev/null)
  if [[ -n "$vsc_driver" && "$vsc_driver" != "rancher.io/local-path" ]] \
     && ! kubectl get csidriver "$vsc_driver" >/dev/null 2>&1; then
    cka_sim::grade::record_trap csi-snapshot-wrong-driver
  fi
fi

# Trap detector: pvc-wrong-storageclass -- PVC storageClassName hand-edited
# away from the seeded 'local-path' SC (candidate bypassed the setup fixture).
pvc_sc=$(kubectl get pvc app-data -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
if [[ -n "$pvc_sc" && "$pvc_sc" != "local-path" ]]; then
  cka_sim::grade::record_trap pvc-wrong-storageclass
fi

# Note: the third metadata-declared trap (reclaim-policy-delete-data-loss)
# has no grade.sh detector -- it is conceptual/documentation-only, listed
# in metadata.yaml for PACK-06 trap-seed completeness. The same pattern
# is used by storage/05 (declares 3 traps, detects 2). A reliable live
# detector for Retain-vs-Delete intent would need a candidate signal this
# question does not supply (the VSC itself has no durable intent field).

cka_sim::grade::emit_result
