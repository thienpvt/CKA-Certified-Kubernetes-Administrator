#!/bin/bash
# storage/04-csi-volumesnapshot/ref-solution.sh
# Reference solution: creates the cluster-scoped VolumeSnapshotClass +
# namespaced VolumeSnapshot the grader expects. Uses the local-path
# provisioner already installed on the candidate's cluster.
#
# Not exposed to candidates during drills; invoked only by the GRADE-06
# round-trip: bash setup.sh && bash ref-solution.sh && bash grade.sh ->
# SCORE = 4/4 + 0 traps.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: q04-snapclass
driver: rancher.io/local-path
deletionPolicy: Delete
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: q04-snapshot
  namespace: ${CKA_SIM_LAB_NS}
spec:
  volumeSnapshotClassName: q04-snapclass
  source:
    persistentVolumeClaimName: app-data
EOF
