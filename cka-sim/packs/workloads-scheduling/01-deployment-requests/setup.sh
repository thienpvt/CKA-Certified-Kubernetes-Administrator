#!/bin/bash
# workloads-scheduling/01-deployment-requests/setup.sh — Deployment WITH default SA, NO requests (the traps).
# Retrofitted Phase 4 Plan 05: sources shared cka-sim/lib/setup.sh helpers.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait.
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-deployment-requests
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-deployment-requests 120

# 2. Deployment with NO resources.requests AND NO serviceAccountName (defaults to "default" SA — the trap).
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-app
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: load-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: load-app
  template:
    metadata:
      labels:
        app: load-app
    spec:
      containers:
        - name: app
          image: nginx:1.27
          ports:
            - containerPort: 80
EOF
