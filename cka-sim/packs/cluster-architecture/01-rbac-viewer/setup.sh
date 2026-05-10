#!/bin/bash
# cluster-architecture/01-rbac-viewer/setup.sh — Role intentionally missing get/list verbs (the trap).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# 1. ns + Active wait
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: cluster-architecture
    cka-sim/question-id: cluster-architecture-rbac-viewer
EOF
phase=""
for i in $(seq 1 10); do
  phase=$(kubectl get ns "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [[ "$phase" == "Active" ]]; then
    break
  fi
  if [[ -z "$phase" ]]; then
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: cluster-architecture
    cka-sim/question-id: cluster-architecture-rbac-viewer
EOF
  fi
  sleep 5
done
[[ "$phase" == "Active" ]] || { echo "ns not Active (phase=$phase)" >&2; exit 1; }

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
