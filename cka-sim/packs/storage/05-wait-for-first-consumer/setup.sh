#!/bin/bash
# storage/05-wait-for-first-consumer/setup.sh — seeds WFFC StorageClass + manual PV + Pending PVC.
# The PVC stays Pending because WFFC defers binding until a consumer Pod is scheduled.
# Sources cka-sim/lib/setup.sh (Plan 04-01) for ns + PV helpers.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait (helper absorbs the --wait=false race).
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-wait-for-first-consumer
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-wait-for-first-consumer 120

# WR-07 (04-REVIEW.md): stamp ownership labels on every cluster-scoped PV emitted
# by seed_pv_hostpath so pack-scoped cleanup/coverage tooling can find them.
export CKA_SIM_PACK="storage"
export CKA_SIM_QUESTION_ID="storage-wait-for-first-consumer"

# 2. StorageClass q05-wffc — no dynamic provisioner, WaitForFirstConsumer binding.
# The binding mode is the crux: PVCs referring to this SC stay Pending until a pod
# that mounts them is scheduled, at which point the binder picks a matching PV.
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: q05-wffc
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-wait-for-first-consumer
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
EOF

# 3. Manual hostPath PV q05-wffc-pv — pinned to any worker node via nodeAffinity on the
# standard kubernetes.io/hostname label. The helper emits a PV with storageClassName=manual;
# we patch it afterwards to match the WFFC StorageClass name (the binder matches by name).
# Cluster-scoped -> q05- prefix per TRIP-03.
cka_sim::setup::seed_pv_hostpath q05-wffc-pv 1Gi ReadWriteOnce Retain /tmp/q05-wffc-pv kubernetes.io/hostname
kubectl patch pv q05-wffc-pv --type=merge -p='{"spec":{"storageClassName":"q05-wffc"}}'

# 4. PVC q05-claim -- stays Pending until a consumer Pod is scheduled (the WFFC trap).
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: q05-claim
  namespace: ${CKA_SIM_LAB_NS}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: q05-wffc
EOF
