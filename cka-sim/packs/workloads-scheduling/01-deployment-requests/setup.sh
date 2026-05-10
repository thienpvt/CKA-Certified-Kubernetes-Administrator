#!/bin/bash
# workloads-scheduling/01-deployment-requests/setup.sh — Deployment WITH default SA, NO requests (the traps).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Idempotent ns + Active wait
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: workloads-scheduling
    cka-sim/question-id: workloads-deployment-requests
EOF
phase=""
for i in $(seq 1 10); do
  phase=$(kubectl get ns "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [[ "$phase" == "Active" ]] && break
  sleep 5
done
[[ "$phase" == "Active" ]] || { echo "ns not Active (phase=$phase)" >&2; exit 1; }

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
