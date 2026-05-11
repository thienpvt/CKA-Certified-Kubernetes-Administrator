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
#
# WR-01 (04-REVIEW.md): the manifests below are fetched live from
# raw.githubusercontent.com without SHA256 verification. Emit a loud warning
# so the supply-chain risk is visible, and provide CKA_SIM_OFFLINE=1 as an
# opt-out that fails fast for air-gapped environments. A follow-up plan will
# vendor the pinned release manifests under cka-sim/vendor/ with recorded
# SHA256 and flip the default to offline-vendored-first.
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
  # WR-12 (04-REVIEW.md): drop || true on this critical gate -- if
  # snapshot-controller never becomes Available, setup must fail loudly so the
  # runner distinguishes "setup broken" from "candidate broken" rather than
  # silently entering an unusable state that grade.sh later reports as if the
  # candidate caused it.
  kubectl wait --for=condition=Available deployment/snapshot-controller -n kube-system --timeout=120s 2>/dev/null \
    || { echo "setup: snapshot-controller did not become Available within 120s" >&2; exit 1; }
fi

# 2. hostpath-csi driver — pinned v1.14.0 reference manifests.
# BUG-4 fix (2026-05-11): upstream v1.14.0 has NO kustomize entrypoint at
# deploy/kubernetes-latest/hostpath. Install the 3 required yamls under
# deploy/kubernetes-1.27/hostpath individually. Manifests land in the
# 'default' namespace; sentinel checks for the StatefulSet.
# BUG-6 fix (2026-05-11): v1.14.0 plugin.yaml defines ClusterRoleBindings
# that reference 5 ClusterRoles living in external-sidecar repos. Apply
# those RBAC manifests FIRST, then the 3 hostpath manifests; otherwise the
# csi-provisioner sidecar gets "forbidden: listing storageclasses" and
# PVC stays Pending with WaitForFirstConsumer forever.
if ! kubectl get statefulset csi-hostpathplugin -n default >/dev/null 2>&1; then
  # 2a. External sidecar ClusterRoles (required by plugin.yaml's ClusterRoleBindings).
  for _q04_url in \
    https://raw.githubusercontent.com/kubernetes-csi/external-provisioner/v4.0.0/deploy/kubernetes/rbac.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/external-attacher/v4.5.0/deploy/kubernetes/rbac.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/external-resizer/v1.10.0/deploy/kubernetes/rbac.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/external-health-monitor/v0.11.0/deploy/kubernetes/external-health-monitor-controller/rbac.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/deploy/kubernetes/csi-snapshotter/rbac-csi-snapshotter.yaml; do
    _q04_warn_unsigned_fetch "$_q04_url"
    kubectl apply -f "$_q04_url"
  done
  # 2b. hostpath driver manifests.
  for _q04_url in \
    https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/v1.14.0/deploy/kubernetes-1.27/hostpath/csi-hostpath-driverinfo.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/v1.14.0/deploy/kubernetes-1.27/hostpath/csi-hostpath-plugin.yaml \
    https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/v1.14.0/deploy/kubernetes-1.27/hostpath/csi-hostpath-snapshotclass.yaml; do
    _q04_warn_unsigned_fetch "$_q04_url"
    kubectl apply -f "$_q04_url"
  done
  # WR-12: fail loudly if plugin pods never come up.
  kubectl wait --for=condition=Ready pod -n default \
    -l app.kubernetes.io/name=csi-hostpathplugin \
    --timeout=180s 2>/dev/null \
    || { echo "setup: csi-hostpathplugin pods did not reach Ready within 180s" >&2; exit 1; }
fi

# BUG-5 fix (2026-05-11): the v1.14.0 csi-driver-host-path is a single-replica
# StatefulSet (csi-hostpathplugin-0) that serves only the node it is scheduled
# on -- hostpath storage is node-local. On a 1+2 kubeadm cluster, the plugin
# lands on one worker while kube-scheduler can place q04-writer on any node;
# when writer lands off-plugin-node, the PVC never binds (WaitForFirstConsumer
# plus node-local driver). Pin q04-writer to the plugin's node explicitly.
# Fail loud if discovery returns empty -- the Ready wait above should have
# caught that, but double-guard so the failure mode is obvious.
CSI_HOSTPATH_NODE=$(kubectl get pod csi-hostpathplugin-0 -n default \
  -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "")
if [[ -z "$CSI_HOSTPATH_NODE" ]]; then
  echo "setup: could not discover csi-hostpathplugin-0 node -- driver install may be broken" >&2
  exit 1
fi
echo "setup: storage/04 writer pod will be pinned to ${CSI_HOSTPATH_NODE} (hostpath-csi plugin node)"

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
  nodeName: ${CSI_HOSTPATH_NODE}
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
# WR-12: fail loudly if the PVC never binds -- the question is unusable without it
# and a silent failure would surface downstream as a candidate-error in grade.sh.
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/app-data -n "$CKA_SIM_LAB_NS" --timeout=180s 2>/dev/null \
  || { echo "setup: pvc/app-data did not reach Bound within 180s (writer pod scheduling / csi-hostpath issue)" >&2; exit 1; }

exit 0
