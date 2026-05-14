#!/bin/bash
set -euo pipefail

sandbox="/tmp/q05-staticpod"
mkdir -p "$sandbox"
cat > "$sandbox/manifest.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: q05-cache
  namespace: kube-system
  labels:
    app.kubernetes.io/name: q05-cache
spec:
  containers:
    - name: cache
      image: nginx:1.27-alpine
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
EOF
