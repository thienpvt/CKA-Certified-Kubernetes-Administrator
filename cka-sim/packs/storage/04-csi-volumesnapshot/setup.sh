#!/bin/bash
# storage/04-csi-volumesnapshot/setup.sh
# Teaches VolumeSnapshot / VolumeSnapshotClass API semantics (CG-01).
# Uses the external-snapshotter controller + a VolumeSnapshotClass for the
# local-path-provisioner already installed on the candidate's cluster.
# The local-path driver does not implement CSI snapshots, so the grader
# asserts schema correctness + controller acceptance, not readyToUse.
#
# Why this shape (vs. the original hostpath-csi-based question):
#   - csi-driver-host-path v1.14.0 has no kustomize entrypoint and its
#     plugin.yaml references five ClusterRoles living in external-sidecar
#     repos, causing 6+ iterations of upstream-compat bugs that do NOT map
#     to CKA curriculum (MH-5 gap closure, 2026-05-11).
#   - local-path-provisioner is already installed on candidate clusters;
#     the only external install here is the snapshot-controller, which is
#     a 2-manifest set that has been stable across every previous drill.
#   - CKA exam tests *conceptual* CSI/snapshot knowledge (reading a
#     VolumeSnapshotClass, creating a VolumeSnapshot, verifying schema),
#     not assembling a driver's RBAC stack.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-csi-volumesnapshot
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-csi-volumesnapshot 120

# Preflight: local-path-provisioner StorageClass must exist. Fail loudly
# with an install hint rather than silently producing a Pending PVC the
# candidate will misread as a cluster problem.
if ! kubectl get storageclass local-path >/dev/null 2>&1; then
  echo "setup: storage/04 requires the local-path-provisioner StorageClass." >&2
  echo "       Install via: kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml" >&2
  echo "       Then re-run: bash cka-sim/lib/cmd/drill.sh storage 4" >&2
  exit 1
fi

# 1. External snapshotter CRDs + snapshot-controller -- pinned v7.0.2.
# Gated on the VolumeSnapshot API kind so other questions / users that already
# installed the CRDs via Helm or kustomize are not disturbed (RESEARCH 6.1 +
# 9 risk: "VolumeSnapshot CRD install changes ownership over time").
#
# WR-01 (04-REVIEW.md): the manifests below are fetched live from
# raw.githubusercontent.com without SHA256 verification. Emit a loud warning
# so the supply-chain risk is visible, and provide CKA_SIM_OFFLINE=1 as an
# opt-out that fails fast for air-gapped environments.
_q04_warn_unsigned_fetch() {
  local url="$1"
  echo "WARN: storage/04 fetching unsigned manifest from $url (WR-01 pending full vendoring)" >&2
}
if [[ "${CKA_SIM_OFFLINE:-0}" == "1" ]]; then
  echo "setup: CKA_SIM_OFFLINE=1 set and storage/04 has no vendored manifests yet." >&2
  echo "       Unset CKA_SIM_OFFLINE to allow network fetch, or wait for the" >&2
  echo "       vendoring plan that addresses WR-01 in 04-REVIEW.md." >&2
  exit 1
fi
if ! kubectl api-resources --api-group=snapshot.storage.k8s.io 2>/dev/null | grep -q volumesnapshots; then
  for _q04_url in \
    https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml; do
    _q04_warn_unsigned_fetch "$_q04_url"
    kubectl apply -f "$_q04_url"
  done
  # WR-12 (04-REVIEW.md): no '|| true' on this critical gate -- if the
  # snapshot-controller never becomes Available, setup must fail loudly so
  # the runner distinguishes "setup broken" from "candidate broken" rather
  # than silently entering an unusable state that grade.sh later reports as
  # a candidate error.
  kubectl wait --for=condition=Available deployment/snapshot-controller -n kube-system --timeout=120s 2>/dev/null \
    || { echo "setup: snapshot-controller did not become Available within 120s" >&2; exit 1; }
fi

# 2. Seed a PVC + writer pod via local-path StorageClass. local-path uses
# volumeBindingMode=WaitForFirstConsumer so the PVC only binds once the
# writer Pod is scheduled; the wait at the bottom covers that.
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-csi-volumesnapshot
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
  storageClassName: local-path
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

# WR-12: fail loudly if the PVC never binds -- without a Bound PVC the
# VolumeSnapshot CR the candidate writes cannot reference anything real,
# and the failure would surface downstream as a candidate error.
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/app-data -n "$CKA_SIM_LAB_NS" --timeout=120s 2>/dev/null \
  || { echo "setup: pvc/app-data did not reach Bound within 120s (local-path-provisioner not healthy?)" >&2; exit 1; }

exit 0
