#!/bin/bash
# storage/04-csi-volumesnapshot/reset.sh
# Question-scoped: async ns delete. Driver-scoped: tear down the csi-hostpath
# driver + StorageClass + VolumeSnapshotClass ONLY IF (a) kubectl queries
# succeed AND (b) no OTHER lab namespace still has a PVC labelled
# cka-sim/uses=csi-hostpath AND (c) no VolumeSnapshot resources exist.
# Per CR-03 (04-REVIEW.md): kubectl failures (API timeout, RBAC deny, TLS
# error) must NOT collapse to "0 active users" -- that would tear down the
# shared driver and break every concurrent lab. Capture exit codes
# explicitly and skip teardown on any error (fail closed / fail safe).
# Leaves the snapshot CRDs installed -- ripping them out is destructive
# across any co-tenant using VolumeSnapshots.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (runner owns synchronous waits).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Driver refcount. Exclude the namespace being torn down so we do not count
# its own PVCs against it (--field-selector metadata.namespace!=<ns>). Capture
# stderr and exit code separately so we can distinguish "succeeded, 0 results"
# (safe to teardown) from "kubectl failed" (unknown state, skip teardown).
set +e
pvc_out=$(kubectl get pvc --all-namespaces -l cka-sim/uses=csi-hostpath \
  --field-selector "metadata.namespace!=$CKA_SIM_LAB_NS" \
  -o name 2>/dev/null)
pvc_rc=$?
snap_out=$(kubectl get volumesnapshot --all-namespaces -o name 2>/dev/null)
snap_rc=$?
set -e

if (( pvc_rc != 0 )) || (( snap_rc != 0 )); then
  echo "reset: skipping csi-hostpath driver teardown -- kubectl query failed (pvc_rc=$pvc_rc snap_rc=$snap_rc); driver left standing for safety" >&2
  exit 0
fi

if [[ -z "$pvc_out" && -z "$snap_out" ]]; then
  kubectl delete volumesnapshotclass csi-hostpath-snapshotclass --ignore-not-found
  kubectl delete storageclass csi-hostpath-sc --ignore-not-found
  kubectl delete namespace csi-hostpath --ignore-not-found --wait=false
fi

exit 0
