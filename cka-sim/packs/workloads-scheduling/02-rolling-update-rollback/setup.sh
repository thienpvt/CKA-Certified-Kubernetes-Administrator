#!/bin/bash
# workloads-scheduling/02-rolling-update-rollback/setup.sh — Deployment web at nginx:1.25 with RollingUpdate
# strategy and multiple revisions so `kubectl rollout undo` has prior history to return to.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait.
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-rolling-update-rollback
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-rolling-update-rollback 120

# 2. Deployment with RollingUpdate strategy at nginx:1.25 — carries the three traps:
#    - deployment-missing-requests  (no resources.requests)
#    - default-sa-used              (no spec.serviceAccountName)
#    - service-selector-empty-endpoints (no Service yet; candidate could notice the rollout is
#      not fronted by a stable endpoint set — relevant once a Service exists).
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: web
  annotations:
    kubernetes.io/change-cause: "initial nginx:1.25"
spec:
  replicas: 2
  revisionHistoryLimit: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: app
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF

kubectl rollout status deployment/web -n "$CKA_SIM_LAB_NS" --timeout=120s 2>/dev/null || true

# 3. Seed a second revision so `rollout undo` has something to go back to.
#    Patch a harmless template annotation — this triggers a new rollout revision
#    while keeping the image at nginx:1.25 (the candidate's post-rollback target).
kubectl annotate deployment web -n "$CKA_SIM_LAB_NS" --overwrite kubernetes.io/change-cause="revision 2 — annotation bump"
kubectl patch deployment web -n "$CKA_SIM_LAB_NS" --type=json \
  -p='[{"op":"add","path":"/spec/template/metadata/annotations","value":{"cka-sim/rev":"2"}}]' 2>/dev/null || true
kubectl rollout status deployment/web -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
