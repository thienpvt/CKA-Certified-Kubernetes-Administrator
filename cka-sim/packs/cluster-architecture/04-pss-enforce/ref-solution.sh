#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q04-pss-enforce"
mkdir -p "$sandbox"
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
kubectl apply --dry-run=server -f "$sandbox/violator.yaml" 2>&1 | tee "$sandbox/violator-admission.log" >/dev/null || true
cat > "$sandbox/admission-config.yaml" <<'EOF'
# Reference only. This file is not applied to the live apiserver.
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: PodSecurity
    configuration:
      apiVersion: pod-security.admission.config.k8s.io/v1
      kind: PodSecurityConfiguration
      exemptions:
        usernames: []
        runtimeClasses: []
        namespaces: []
EOF
