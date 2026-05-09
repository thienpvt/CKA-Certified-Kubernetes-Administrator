#!/bin/bash
# cka-sim/tests/cases/traps_missing-dns-egress.sh — verifies detect_missing_dns_egress (D-12 hit/miss/benign).
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# ---------- hit: egress policy restricts egress but omits UDP/53 -> fires ----------
export CKA_SIM_TEST_CURRENT="missing-dns-egress/hit"
r=$(cka_sim::trap::detect_missing_dns_egress cka-sim-test deny-extra || true)
expect_eq "$r" "missing-dns-egress" "hit: egress policy without UDP/53 fires trap" || case_failed=1

# ---------- miss: egress policy includes explicit UDP/53 allow -> does not fire ----------
export CKA_SIM_TEST_CURRENT="missing-dns-egress/miss"
r=$(cka_sim::trap::detect_missing_dns_egress cka-sim-test allow-with-dns || true)
expect_empty "$r" "miss: egress policy with UDP/53 does not fire" || case_failed=1

# ---------- benign: ingress-only policy (no egress restriction) -> does not fire ----------
export CKA_SIM_TEST_CURRENT="missing-dns-egress/benign"
r=$(cka_sim::trap::detect_missing_dns_egress cka-sim-test ingress-only || true)
expect_empty "$r" "benign: ingress-only policy does not fire" || case_failed=1

exit "$case_failed"
