#!/bin/bash
# storage/04-csi-volumesnapshot/reset.sh
# Tears down the lab. No driver uninstall here -- the shared
# external-snapshotter controller stays installed across drills (ripping
# out the CRDs would break every co-tenant using VolumeSnapshots).
#
# D-09: runner owns ns cleanup; this is the question-level teardown for
# cluster-scoped artefacts (q04-snapclass) that ns deletion cannot sweep.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# Cluster-scoped VolumeSnapshotClass authored by the candidate (q-prefix).
kubectl delete volumesnapshotclass q04-snapclass --ignore-not-found

# Async ns delete -- takes PVC, VolumeSnapshot, and writer pod with it.
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/storage-csi-volumesnapshot/"

exit 0
