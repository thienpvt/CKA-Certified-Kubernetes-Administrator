#!/bin/bash
# cka-sim/tests/cases/traps_kubelet-runtime-flag-in-kubeconfig.sh — verifies detect_kubelet_runtime_flag_in_kubeconfig.
# TEXT detector: no fixture JSON needed; inputs live inline.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

export CKA_SIM_TEST_CURRENT="kubelet-runtime-flag-in-kubeconfig/text"

case_failed=0

# ---------- hit: edits kubelet.conf AND adds --container-runtime flag ----------
hit_text='sed -i "s|--container-runtime=containerd|--container-runtime=remote|" /etc/kubernetes/kubelet.conf'
r=$(cka_sim::trap::detect_kubelet_runtime_flag_in_kubeconfig "$hit_text" || true)
expect_eq "$r" "kubelet-runtime-flag-in-kubeconfig" "hit: container-runtime flag in kubelet.conf fires trap" || case_failed=1

# ---------- miss: edits kubeadm-flags.env (the correct file) ----------
miss_text='sed -i "s|.*|--container-runtime-endpoint=unix:///run/cri-dockerd.sock|" /var/lib/kubelet/kubeadm-flags.env'
r=$(cka_sim::trap::detect_kubelet_runtime_flag_in_kubeconfig "$miss_text" || true)
expect_empty "$r" "miss: edits correct kubeadm-flags.env (not kubelet.conf) does not fire" || case_failed=1

# ---------- benign: reads kubelet.conf but no --container-runtime flag ----------
benign_text='cat /etc/kubernetes/kubelet.conf  # inspect kubeconfig'
r=$(cka_sim::trap::detect_kubelet_runtime_flag_in_kubeconfig "$benign_text" || true)
expect_empty "$r" "benign: reads kubelet.conf with no runtime flag does not fire" || case_failed=1

exit "$case_failed"
