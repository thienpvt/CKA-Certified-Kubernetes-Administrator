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

# WR-07 (04-REVIEW.md): stamp ownership labels on every cluster-scoped PV emitted
# by seed_pv_hostpath so pack-scoped cleanup/coverage tooling can find them.
export CKA_SIM_PACK="storage"
export CKA_SIM_QUESTION_ID="storage-pvc-mount-pod"

# 2. Seed hostPath PV pinned to ONE specific worker (CR-01 fix).
#    Writer + reader (candidate's Deployment) will both be placed on that node
#    because the scheduler honors PV nodeAffinity; guarantees the /data/marker
#    written by q06-writer is visible to q06-reader on the same hostPath fs.
#    If no worker label is discoverable, pin to whichever node has the first
#    kubernetes.io/hostname value -- single-node kind clusters still work.
q06_pin_node=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$q06_pin_node" ]]; then
  q06_pin_node=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi
: "${q06_pin_node:?could not discover a node to pin q06-data-pv to}"
cka_sim::setup::seed_pv_hostpath q06-data-pv 1Gi ReadWriteOnce Retain /tmp/q06-data "kubernetes.io/hostname=${q06_pin_node}"

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
#    WR-10 (04-REVIEW.md): reset.sh uses async ns delete (--wait=false) + cluster-
#    scoped PV delete, so the hostPath directory on the pinned node can retain a
#    stale /data/marker from a prior run's writer until kubelet GC catches up. Add
#    an initContainer that wipes /data before the writer populates it, so every
#    setup run starts from a clean filesystem regardless of reset's async race.
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
  initContainers:
    - name: wipe
      image: busybox:1.36
      command: ["sh", "-c", "rm -rf /data/* /data/.[!.]* 2>/dev/null; true"]
      volumeMounts:
        - name: data
          mountPath: /data
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
