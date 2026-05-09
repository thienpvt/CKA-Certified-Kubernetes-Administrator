#!/bin/bash
# cka-sim/tests/cases/traps_default-sa-used.sh — verifies detect_default_sa_used (D-12 hit/miss/benign).
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# ---------- hit: pod with no serviceAccountName -> fires ----------
export CKA_SIM_TEST_CURRENT="default-sa-used/hit"
r=$(cka_sim::trap::detect_default_sa_used cka-sim-test webapp || true)
expect_eq "$r" "default-sa-used" "hit: pod with no SA fires trap" || case_failed=1

# ---------- miss: pod with dedicated SA -> does not fire ----------
export CKA_SIM_TEST_CURRENT="default-sa-used/miss"
r=$(cka_sim::trap::detect_default_sa_used cka-sim-test webapp || true)
expect_empty "$r" "miss: pod with dedicated SA does not fire" || case_failed=1

# ---------- benign: unrelated pod with monitoring SA -> does not fire ----------
export CKA_SIM_TEST_CURRENT="default-sa-used/benign"
r=$(cka_sim::trap::detect_default_sa_used cka-sim-test other-pod || true)
expect_empty "$r" "benign: unrelated pod with non-default SA does not fire" || case_failed=1

exit "$case_failed"
