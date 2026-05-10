#!/bin/bash
# storage/06-pvc-mount-pod/setup.sh — seeds namespace + Bound PVC q06-data with
# pre-written marker file via an ephemeral writer pod. Candidate then authors a
# Deployment q06-reader that mounts the PVC read-only and can cat the marker.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait.
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-pvc-mount-pod
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-pvc-mount-pod 120

# 2. Seed hostPath PV with nodeAffinity (correctly pinned — not the trap here).
#    storageClassName=manual matches the PVC below so the pair binds immediately.
cka_sim::setup::seed_pv_hostpath q06-data-pv 1Gi ReadWriteOnce Retain /tmp/q06-data kubernetes.io/hostname

# 3. Apply PVC — binds against q06-data-pv via storageClassName=manual.
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: q06-data
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-mount-pod
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
  volumeName: q06-data-pv
EOF

# Wait for Bound before launching writer (writer would stay Pending otherwise).
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/q06-data \
  -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true

# 4. Writer pod: runs once, writes /data/marker, exits 0. restartPolicy=OnFailure
#    keeps the pod from restarting after a successful write (terminal Succeeded).
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q06-writer
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-mount-pod
spec:
  restartPolicy: OnFailure
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo q06-marker > /data/marker && sync"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: q06-data
EOF

# Wait for writer to finish. Best-effort: if the cluster is slow, the grader's
# Deployment exec probe still exercises the marker read path.
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/q06-writer \
  -n "$CKA_SIM_LAB_NS" --timeout=90s 2>/dev/null || true
