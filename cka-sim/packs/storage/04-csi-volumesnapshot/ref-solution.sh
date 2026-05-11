#!/bin/bash
# storage/04-csi-volumesnapshot/ref-solution.sh
# GRADE-06 round-trip reference: creates the VolumeSnapshot that grade.sh expects.
# Invoked by the round-trip harness: bash setup.sh && bash ref-solution.sh && bash grade.sh
# must produce SCORE = max + 0 traps.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: q04-app-snapshot
  namespace: ${CKA_SIM_LAB_NS}
spec:
  volumeSnapshotClassName: csi-hostpath-snapshotclass
  source:
    persistentVolumeClaimName: app-data
EOF

# Snapshot controller + hostpath-csi externalsnapshotter need a moment to drive
# the snapshot to readyToUse=true. Timeout aligned with upstream CI (~60-90s).
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/q04-app-snapshot -n "$CKA_SIM_LAB_NS" --timeout=120s
