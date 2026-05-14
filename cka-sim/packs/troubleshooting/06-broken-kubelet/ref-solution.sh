#!/bin/bash
set -euo pipefail

sandbox="/tmp/q06-kubelet-flags"
mkdir -p "$sandbox"
cat > "$sandbox/kubeadm-flags.env" <<'EOF'
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/cri-dockerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10"
EOF
: > "$sandbox/kubelet.conf"
