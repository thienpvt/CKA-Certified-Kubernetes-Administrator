#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="cluster-architecture"
CKA_SIM_QUESTION_ID="cluster-architecture-kubeadm-upgrade"
sandbox="/tmp/q03-kubeadm-upgrade"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"

mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"
printf 'v1.34.2\n' > "$sandbox/current-version.txt"
cat > "$sandbox/kubeadm-upgrade-plan.txt" <<'EOF'
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT   TARGET
kubelet     v1.34.2   v1.35.0
kube-proxy  v1.34.2   v1.35.0
etcd        3.5.x     3.5.x
target version: v1.35.0
EOF
: > "$sandbox/planned-upgrade.txt"
: > "$sandbox/apply-script.sh"
chmod 0644 "$sandbox/planned-upgrade.txt" "$sandbox/apply-script.sh"
