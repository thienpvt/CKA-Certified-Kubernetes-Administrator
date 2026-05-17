#!/bin/bash
# storage/01-pvc-binding/setup.sh — seeds hostPath PV WITHOUT nodeAffinity (trap) + PVC.
# Retrofitted Phase 4 Plan 04: sources shared cka-sim/lib/setup.sh helpers.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait (helper absorbs the --wait=false race).
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-pvc-binding
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-pvc-binding 120

# 2. Apply hostPath PV — INTENTIONALLY MISSING nodeAffinity (the trap).
# Cluster-scoped -> q01- prefix per TRIP-03.
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: q01-app-pv
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-binding
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/q01-app-pv
    type: DirectoryOrCreate
EOF

# 3. Apply PVC (will stay Pending until candidate fixes the PV's nodeAffinity).
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: ${CKA_SIM_LAB_NS}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF

# 4. Apply consumer Pod that mounts app-data — Pod stays Pending until candidate fixes the PV's nodeAffinity (real symptom of the trap).
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q01-app-consumer
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-binding
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-data
EOF
