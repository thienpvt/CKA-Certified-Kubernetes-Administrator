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

# WR-02 (04-REVIEW.md): preflight the dynamic provisioner dependency. The
# ref-solution creates a StorageClass with provisioner rancher.io/local-path,
# which is assumed pre-installed "per exercise 12". On a fresh kubeadm cluster
# without that provisioner, the ref-solution-based GRADE-06 round-trip and the
# cka-sim drill storage run both hang at PVC Bound wait until the 90s timeout.
# Fail fast with a clear message instead. Accept ANY provisioner other than
# kubernetes.io/no-provisioner (rancher/local-path, csi-hostpath, cloud CSIs
# all qualify) so the question stays portable across kubeadm + kind + cloud.
if ! kubectl get sc -o jsonpath='{range .items[*]}{.provisioner}{"\n"}{end}' 2>/dev/null \
    | grep -v '^kubernetes\.io/no-provisioner$' | grep -q .; then
  echo "setup: no dynamic provisioner StorageClass found on this cluster." >&2
  echo "       storage/02 requires a working dynamic provisioner (e.g." >&2
  echo "       rancher.io/local-path from exercise 12, or csi-hostpath)." >&2
  echo "       Run exercise 12's local-path-provisioner install, or this" >&2
  echo "       question's ref-solution will hang at PVC Bound." >&2
  exit 1
fi

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
