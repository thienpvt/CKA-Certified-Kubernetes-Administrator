#!/bin/bash
# storage/04-csi-volumesnapshot/reset.sh
# Question-scoped: async ns delete. Driver-scoped: tear down the csi-hostpath
# driver + StorageClass + VolumeSnapshotClass ONLY IF no OTHER lab namespace
# still has a PVC labelled cka-sim/uses=csi-hostpath (the refcount gate from
# RESEARCH §6.1). Leaves the snapshot CRDs installed — ripping them out is
# destructive across any co-tenant using VolumeSnapshots.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (runner owns synchronous waits).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Driver refcount. Exclude the namespace being torn down so we do not count
# its own PVCs against it (--field-selector metadata.namespace!=<ns>).
active_users=$(kubectl get pvc --all-namespaces -l cka-sim/uses=csi-hostpath \
  --field-selector "metadata.namespace!=$CKA_SIM_LAB_NS" \
  -o name 2>/dev/null | wc -l | tr -d ' ')

if [[ "$active_users" == "0" ]]; then
  kubectl delete volumesnapshotclass csi-hostpath-snapshotclass --ignore-not-found
  kubectl delete storageclass csi-hostpath-sc --ignore-not-found
  kubectl delete namespace csi-hostpath --ignore-not-found --wait=false
fi

exit 0
