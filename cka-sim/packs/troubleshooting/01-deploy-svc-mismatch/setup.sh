#!/bin/bash
# troubleshooting/01-deploy-svc-mismatch/setup.sh — Phase 6 retrofit: lib sourcing + web-canary ImagePullBackOff trap.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="troubleshooting"
CKA_SIM_QUESTION_ID="troubleshooting-deploy-svc-mismatch"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID" 120

# 1. Deployment 'web' — pod labels app=web (pinned nginx:1.27-alpine for small/stable/readiness-friendly).
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ${CKA_SIM_LAB_NS}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 3
EOF

# 2. Service 'web-svc' — INTENTIONAL TRAP: selector app=webserver does NOT match deployment pod label app=web.
#    Result: Endpoints for web-svc remain empty despite the Deployment's pods being Ready.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: ${CKA_SIM_LAB_NS}
spec:
  type: ClusterIP
  selector:
    app: webserver
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF

# 3. Deployment 'web-canary' — sibling workload for ImagePullBackOff trap.
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-canary
  namespace: ${CKA_SIM_LAB_NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-canary
  template:
    metadata:
      labels:
        app: web-canary
    spec:
      containers:
        - name: web-canary
          # INTENTIONAL TRAP: image tag does not exist -> ImagePullBackOff
          image: nginx:1.27-alpine-typoXYZ
EOF

# 4. Wait briefly for the healthy deployment (best-effort — the canary never becomes Available).
kubectl wait --for=condition=Available deployment/web -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
