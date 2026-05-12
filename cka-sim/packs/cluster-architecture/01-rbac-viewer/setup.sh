#!/bin/bash
# cluster-architecture/01-rbac-viewer/setup.sh — Role intentionally missing get/list verbs (the trap).
# Retrofitted Phase 5 Plan 08: sources shared cka-sim/lib/setup.sh helpers.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait (helper absorbs the --wait=false race).
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" cluster-architecture cluster-architecture-rbac-viewer
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" cluster-architecture cluster-architecture-rbac-viewer 120

# 2. ServiceAccount 'viewer'
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: viewer
  namespace: ${CKA_SIM_LAB_NS}
EOF

# 3. Role 'pod-viewer' — INTENTIONAL TRAP: only "watch" verb, missing get+list.
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-viewer
  namespace: ${CKA_SIM_LAB_NS}
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["watch"]
EOF

# 4. RoleBinding 'viewer-binding' binding SA viewer to Role pod-viewer
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: viewer-binding
  namespace: ${CKA_SIM_LAB_NS}
subjects:
  - kind: ServiceAccount
    name: viewer
    namespace: ${CKA_SIM_LAB_NS}
roleRef:
  kind: Role
  name: pod-viewer
  apiGroup: rbac.authorization.k8s.io
EOF
