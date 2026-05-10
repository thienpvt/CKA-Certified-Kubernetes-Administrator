#!/bin/bash
# troubleshooting/01-deploy-svc-mismatch/setup.sh — Deployment labels != Service selector (the trap).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# 1. ns + Active wait (handles prior reset --wait=false leaving Terminating ns)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: troubleshooting
    cka-sim/question-id: troubleshooting-deploy-svc-mismatch
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
    cka-sim/pack: troubleshooting
    cka-sim/question-id: troubleshooting-deploy-svc-mismatch
EOF
  fi
  sleep 5
done
[[ "$phase" == "Active" ]] || { echo "ns $CKA_SIM_LAB_NS not Active after 50s (phase=$phase)" >&2; exit 1; }

# 2. Deployment 'web' — pod labels app=web (pinned nginx:1.27-alpine for small/stable/readiness-friendly).
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

# 3. Service 'web-svc' — INTENTIONAL TRAP: selector app=webserver does NOT match deployment pod label app=web.
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

# 4. Wait briefly for pods (best-effort — grade.sh re-checks).
kubectl wait --for=condition=Available deployment/web -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
