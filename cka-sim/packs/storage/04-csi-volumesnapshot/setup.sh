#!/bin/bash
# storage/04-csi-volumesnapshot/setup.sh
# Idempotently installs the external-snapshotter CRDs/controller (v7.0.2) and
# the kubernetes-csi/csi-driver-host-path reference driver (v1.14.0), then
# seeds a PVC `app-data` + writer pod that drops /data/marker.
# Install is gated behind sentinels:
#   - api-resources for snapshot.storage.k8s.io/volumesnapshots
#   - namespace csi-hostpath exists
# so re-running the question (TRIP-02) is a no-op after the first run.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-csi-volumesnapshot
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-csi-volumesnapshot 120

# 1. Snapshot CRDs + snapshot-controller — pinned external-snapshotter v7.0.2.
# Gated on the VolumeSnapshot API kind so other questions / users that already
# installed the CRDs via Helm or kustomize are not disturbed (RESEARCH §6.1 +
# §9 risk: "VolumeSnapshot CRD install changes ownership over time").
if ! kubectl api-resources --api-group=snapshot.storage.k8s.io 2>/dev/null | grep -q volumesnapshots; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
  kubectl wait --for=condition=Available deployment/snapshot-controller -n kube-system --timeout=120s 2>/dev/null || true
fi

# 2. hostpath-csi driver — pinned v1.14.0 via kustomize ref.
# Gated on the csi-hostpath namespace existing (the driver's canonical namespace).
if ! kubectl get namespace csi-hostpath >/dev/null 2>&1; then
  kubectl apply -k 'https://github.com/kubernetes-csi/csi-driver-host-path/deploy/kubernetes-latest/hostpath?ref=v1.14.0'
  kubectl wait --for=condition=Ready pod -n csi-hostpath -l app.kubernetes.io/name=csi-hostpathplugin --timeout=180s 2>/dev/null || true
fi

# 3. VolumeSnapshotClass + StorageClass. Labelled so reset.sh can refcount
# other labs still using the driver before tearing it down.
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-hostpath-snapshotclass
  labels:
    cka-sim/uses: csi-hostpath
driver: hostpath.csi.k8s.io
deletionPolicy: Delete
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-hostpath-sc
  labels:
    cka-sim/uses: csi-hostpath
provisioner: hostpath.csi.k8s.io
volumeBindingMode: WaitForFirstConsumer
EOF

# 4. Seed the PVC + writer pod. PVC carries cka-sim/uses=csi-hostpath so
# reset.sh's refcount across lab namespaces works without enumerating packs.
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/uses: csi-hostpath
    cka-sim/pack: storage
    cka-sim/question-id: storage-csi-volumesnapshot
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: csi-hostpath-sc
---
apiVersion: v1
kind: Pod
metadata:
  name: q04-writer
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-csi-volumesnapshot
spec:
  restartPolicy: OnFailure
  containers:
    - name: writer
      image: busybox:1.36
      command:
        - sh
        - -c
        - 'echo q04-marker > /data/marker && sleep 3600'
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-data
EOF

# WaitForFirstConsumer: PVC only transitions to Bound once the writer pod is scheduled.
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/app-data -n "$CKA_SIM_LAB_NS" --timeout=180s 2>/dev/null || true

exit 0
