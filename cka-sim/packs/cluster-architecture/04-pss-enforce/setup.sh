#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="cluster-architecture"
CKA_SIM_QUESTION_ID="cluster-architecture-pss-enforce"
sandbox="/tmp/q04-pss-enforce"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
kubectl label namespace "$CKA_SIM_LAB_NS" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.35 \
  --overwrite
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"

mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q04-compliant
  namespace: ${CKA_SIM_LAB_NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q04-compliant
  template:
    metadata:
      labels:
        app: q04-compliant
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          image: nginxinc/nginx-unprivileged:1.27-alpine
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
EOF

cat > "$sandbox/violator.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q04-violator
  namespace: ${CKA_SIM_LAB_NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q04-violator
  template:
    metadata:
      labels:
        app: q04-violator
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          securityContext:
            privileged: true
EOF

kubectl apply --dry-run=server -f "$sandbox/violator.yaml" 2>&1 | tee "$sandbox/violator-admission.log" >/dev/null || true
