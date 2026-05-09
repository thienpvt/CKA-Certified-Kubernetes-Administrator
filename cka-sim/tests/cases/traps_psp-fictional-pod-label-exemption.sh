#!/bin/bash
# cka-sim/tests/cases/traps_psp-fictional-pod-label-exemption.sh — verifies detect_psp_fictional_pod_label_exemption.
# TEXT detector: no fixture JSON needed; inputs live inline.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

export CKA_SIM_TEST_CURRENT="psp-fictional-pod-label-exemption/text"

case_failed=0

# ---------- hit: uses the fictional pod-level exemption label ----------
hit_text=$'metadata:\n  labels:\n    pod-security.kubernetes.io/exempt: "true"\n  name: privileged-pod'
r=$(cka_sim::trap::detect_psp_fictional_pod_label_exemption "$hit_text" || true)
expect_eq "$r" "psp-fictional-pod-label-exemption" "hit: fictional exemption label fires trap" || case_failed=1

# ---------- miss: labels without the exempt key ----------
miss_text=$'metadata:\n  labels:\n    app: privileged-pod\n  name: privileged-pod'
r=$(cka_sim::trap::detect_psp_fictional_pod_label_exemption "$miss_text" || true)
expect_empty "$r" "miss: normal labels do not fire" || case_failed=1

# ---------- benign: regular pod YAML, no labels at all ----------
benign_text=$'apiVersion: v1\nkind: Pod\nmetadata:\n  name: regular-pod'
r=$(cka_sim::trap::detect_psp_fictional_pod_label_exemption "$benign_text" || true)
expect_empty "$r" "benign: pod without exemption label does not fire" || case_failed=1

exit "$case_failed"
