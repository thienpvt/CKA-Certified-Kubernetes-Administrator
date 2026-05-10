#!/bin/bash
# storage/02-storageclass-dynamic/setup.sh — seeds PVC app-cache requesting missing SC fast-ssd.
# Candidate must create a StorageClass named fast-ssd with a working dynamic provisioner.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait (helper absorbs the --wait=false race).
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-storageclass-dynamic
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-storageclass-dynamic 120

# 2. PVC referencing StorageClass fast-ssd (absent from the cluster -> stuck Pending).
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-cache
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-storageclass-dynamic
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: fast-ssd
EOF
