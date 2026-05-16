#!/bin/bash
# cka-sim/tests/cases/traps_as-flag-format-wrong.sh — verifies detect_as_flag_format_wrong.
# TEXT detector: no fixture JSON needed; inputs live inline.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

export CKA_SIM_TEST_CURRENT="as-flag-format-wrong/text"

case_failed=0

# ---------- hit: --as= value has a colon but isn't system:serviceaccount:NS:NAME ----------
hit_text='kubectl auth can-i get pods --as=my-sa:foo'
r=$(cka_sim::trap::detect_as_flag_format_wrong "$hit_text" || true)
expect_eq "$r" "as-flag-format-wrong" "hit: colon-containing --as value in wrong shape fires trap" || case_failed=1

# ---------- miss: properly-formatted system:serviceaccount:NS:NAME ----------
miss_text='kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa'
r=$(cka_sim::trap::detect_as_flag_format_wrong "$miss_text" || true)
expect_empty "$r" "miss: canonical system:serviceaccount form does not fire" || case_failed=1

# ---------- benign: plain username (no colon) ----------
benign_text='kubectl auth can-i get pods --as=alice'
r=$(cka_sim::trap::detect_as_flag_format_wrong "$benign_text" || true)
expect_empty "$r" "benign: plain username does not fire" || case_failed=1

exit "$case_failed"
