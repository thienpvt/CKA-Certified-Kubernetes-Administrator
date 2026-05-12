#!/bin/bash
# troubleshooting/02-netpol-dns-egress/setup.sh — two-stage namespace-local connectivity failure.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="troubleshooting"
CKA_SIM_QUESTION_ID="troubleshooting-netpol-dns-egress"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID" 120

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ${CKA_SIM_LAB_NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: web
  template:
    metadata:
      labels:
        app.kubernetes.io/name: web
    spec:
      containers:
        - name: web
          image: nicolaka/netshoot:v0.13
          command: ["sleep", "3600"]
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ${CKA_SIM_LAB_NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: api
    spec:
      containers:
        - name: api
          image: hashicorp/http-echo:1.0
          args: ["-listen=:8080", "-text=api-ok"]
          ports:
            - containerPort: 8080
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: ${CKA_SIM_LAB_NS}
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: api
  ports:
    - port: 8080
      targetPort: 8080
EOF

# INTENTIONAL TRAP: all egress starts denied; scoped allows must restore required flows.
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: ${CKA_SIM_LAB_NS}
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress: []
EOF

# INTENTIONAL TRAP: selector key does not match the web pod label, and no name resolution allow exists.
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
  namespace: ${CKA_SIM_LAB_NS}
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: api
      ports:
        - protocol: TCP
          port: 8080
EOF

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=web -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
