#!/bin/bash
# storage/03-access-modes-reclaim/setup.sh — seeds 2 PVs + 2 PVCs where
# q03-rwo-pvc binds immediately and q03-rwx-pvc stays Pending (RWX request
# on all-RWO PVs — pv-accessmodes-mismatch trap). Sources lib/setup.sh.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait (helper absorbs reset --wait=false race).
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-access-modes-reclaim
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-access-modes-reclaim 120

# 2. PV 1: RWO, Retain — binds q03-rwo-pvc. Candidate flips reclaim to Delete.
cka_sim::setup::seed_pv_hostpath q03-retain-pv 1Gi ReadWriteOnce Retain /tmp/q03-retain kubernetes.io/hostname

# 3. PV 2: starts RWO, Delete. Candidate patches accessModes to RWX so q03-rwx-pvc can bind.
cka_sim::setup::seed_pv_hostpath q03-delete-pv 1Gi ReadWriteOnce Delete /tmp/q03-delete kubernetes.io/hostname

# WR-04 (04-REVIEW.md): label both PVs so the grader's RWX-detector can scope its
# kubectl get pv query to this question and avoid false negatives from RWX PVs
# left on the cluster by concurrent labs or long-running workloads.
kubectl label pv q03-retain-pv cka-sim/pack=storage cka-sim/question-id=storage-access-modes-reclaim --overwrite
kubectl label pv q03-delete-pv cka-sim/pack=storage cka-sim/question-id=storage-access-modes-reclaim --overwrite

# 4. PVC q03-rwo-pvc (RWO) — binds immediately to q03-retain-pv.
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: q03-rwo-pvc
  namespace: ${CKA_SIM_LAB_NS}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF

# 5. PVC q03-rwx-pvc (RWX) — stays Pending because both PVs are currently RWO.
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: q03-rwx-pvc
  namespace: ${CKA_SIM_LAB_NS}
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF
