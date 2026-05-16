#!/bin/bash
# cka-sim/tests/cases/traps_pss-error-string-mismatch.sh — verifies detect_pss_error_string_mismatch.
# TEXT detector: no fixture JSON needed; inputs live inline.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

# Text-only detector still needs CKA_SIM_TEST_CURRENT for uniformity (kubectl stub is never invoked).
export CKA_SIM_TEST_CURRENT="pss-error-string-mismatch/text"

case_failed=0

# ---------- hit: uses legacy PodSecurityPolicy wording ----------
hit_text='# Error: pods "restricted-test" is forbidden: violates PodSecurityPolicy: privileged: true'
r=$(cka_sim::trap::detect_pss_error_string_mismatch "$hit_text" || true)
expect_eq "$r" "pss-error-string-mismatch" "hit: legacy PSP wording fires trap" || case_failed=1

# ---------- miss: uses v1.25+ PodSecurity wording ----------
miss_text='# Error: pods "restricted-test" is forbidden: violates PodSecurity "restricted:v1.35"'
r=$(cka_sim::trap::detect_pss_error_string_mismatch "$miss_text" || true)
expect_empty "$r" "miss: correct PSS wording does not fire" || case_failed=1

# ---------- benign: unrelated text ----------
benign_text='# All pods running normally'
r=$(cka_sim::trap::detect_pss_error_string_mismatch "$benign_text" || true)
expect_empty "$r" "benign: unrelated text does not fire" || case_failed=1

exit "$case_failed"
