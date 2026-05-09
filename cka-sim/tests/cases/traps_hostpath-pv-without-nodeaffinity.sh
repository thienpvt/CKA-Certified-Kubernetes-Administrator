#!/bin/bash
# cka-sim/tests/cases/traps_hostpath-pv-without-nodeaffinity.sh — verifies detect_hostpath_pv_without_nodeaffinity (D-12).
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# ---------- hit: hostPath PV without nodeAffinity -> fires ----------
export CKA_SIM_TEST_CURRENT="hostpath-pv-without-nodeaffinity/hit"
r=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity data-hostpath || true)
expect_eq "$r" "hostpath-pv-without-nodeaffinity" "hit: hostPath PV without nodeAffinity fires trap" || case_failed=1

# ---------- miss: hostPath PV WITH nodeAffinity -> does not fire ----------
export CKA_SIM_TEST_CURRENT="hostpath-pv-without-nodeaffinity/miss"
r=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity data-hostpath-pinned || true)
expect_empty "$r" "miss: hostPath PV with nodeAffinity does not fire" || case_failed=1

# ---------- benign: CSI-backed PV (no hostPath at all) -> does not fire ----------
export CKA_SIM_TEST_CURRENT="hostpath-pv-without-nodeaffinity/benign"
r=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity data-csi || true)
expect_empty "$r" "benign: CSI PV (no hostPath) does not fire" || case_failed=1

exit "$case_failed"
