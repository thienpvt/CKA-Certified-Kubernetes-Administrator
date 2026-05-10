#!/bin/bash
# storage/01-pvc-binding/setup.sh — seeds hostPath PV WITHOUT nodeAffinity (trap) + PVC.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Idempotent ns create
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-binding
EOF

# 2. Wait up to 50s for ns Active (handles prior reset --wait=false leaving Terminating)
phase=""
for i in $(seq 1 10); do
  phase=$(kubectl get ns "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [[ "$phase" == "Active" ]]; then
    break
  fi
  if [[ -z "$phase" ]]; then
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-binding
EOF
  fi
  sleep 5
done
[[ "$phase" == "Active" ]] || { echo "ns $CKA_SIM_LAB_NS not Active after 50s (phase=$phase)" >&2; exit 1; }

# 3. Apply hostPath PV — INTENTIONALLY MISSING nodeAffinity (the trap).
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

# 4. Apply PVC (will stay Pending until candidate fixes the PV's nodeAffinity).
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
