#!/bin/bash
# cka-sim/tests/cases/traps_removed-container-runtime-flag.sh — verifies detect_removed_container_runtime_flag.
# TEXT detector: no fixture JSON needed; inputs live inline.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

export CKA_SIM_TEST_CURRENT="removed-container-runtime-flag/text"

case_failed=0

# ---------- hit: uses the removed --container-runtime=remote flag ----------
hit_text='kubelet --container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock'
r=$(cka_sim::trap::detect_removed_container_runtime_flag "$hit_text" || true)
expect_eq "$r" "removed-container-runtime-flag" "hit: --container-runtime=remote fires trap" || case_failed=1

# ---------- miss: only --container-runtime-endpoint= (the surviving flag) ----------
miss_text='kubelet --container-runtime-endpoint=unix:///run/cri-dockerd.sock'
r=$(cka_sim::trap::detect_removed_container_runtime_flag "$miss_text" || true)
expect_empty "$r" "miss: only --container-runtime-endpoint does not fire" || case_failed=1

# ---------- benign: unrelated systemctl call ----------
benign_text='systemctl status kubelet'
r=$(cka_sim::trap::detect_removed_container_runtime_flag "$benign_text" || true)
expect_empty "$r" "benign: no runtime flag mention does not fire" || case_failed=1

exit "$case_failed"
