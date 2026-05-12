#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="cluster-architecture"
CKA_SIM_QUESTION_ID="cluster-architecture-cri-dockerd-endpoint"
sandbox="/tmp/q07-kubelet-flags"
removed_flag="--container-runtime""=remote"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"

mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"
[[ -f /var/lib/kubelet/kubeadm-flags.env ]] && cp -p /var/lib/kubelet/kubeadm-flags.env "$sandbox/kubeadm-flags.env"
[[ -f /etc/kubernetes/kubelet.conf ]] && cp -p /etc/kubernetes/kubelet.conf "$sandbox/kubelet.conf"
printf 'KUBELET_KUBEADM_ARGS="%s --pod-infra-container-image=registry.k8s.io/pause:3.10"\n' "$removed_flag" > "$sandbox/kubeadm-flags.env"
: > "$sandbox/kubelet.conf"
