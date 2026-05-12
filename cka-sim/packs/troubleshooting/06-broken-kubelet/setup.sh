#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="troubleshooting"
CKA_SIM_QUESTION_ID="troubleshooting-broken-kubelet"
sandbox="/tmp/q06-kubelet-flags"
removed_flag="--container-runtime""=remote"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"

mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"
printf 'KUBELET_KUBEADM_ARGS="%s --container-runtime-endpoint=/run/cri-dockerd.sock --pod-"infra-container-image=registry.k8s.io/pause:3.10"\n' "$removed_flag" > "$sandbox/kubeadm-flags.env"
cat > "$sandbox/kubelet.conf" <<'EOF'
# This kubeconfig-shaped placeholder accidentally references runtime flags.
# Runtime args belong in the node-agent flag file, never in kubelet.conf.
# --container-runtime-endpoint=unix:///run/cri-dockerd.sock
EOF
