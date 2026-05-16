#!/bin/bash
set -euo pipefail

mkdir -p /tmp/q07-kubelet-flags
cat > /tmp/q07-kubelet-flags/kubeadm-flags.env <<'EOF'
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/cri-dockerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10"
EOF
