#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="troubleshooting"
CKA_SIM_QUESTION_ID="troubleshooting-static-pod-manifest"
sandbox="/tmp/q05-staticpod"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"

mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"

cat > "$sandbox/manifest-broken.yaml" <<'EOF'
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

grep -P '\t' "$sandbox/manifest-broken.yaml" >/dev/null

cat > "$sandbox/manifest-tagtypo.yaml" <<'EOF'
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
      image: nginx:1.27-alpine-doesnotexistXYZ
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
EOF

cp "$sandbox/manifest-broken.yaml" "$sandbox/manifest.yaml"
