#!/bin/bash
# cka-sim/scripts/test.sh — orchestrates lint-traps + bash unit-test runner.
# Local: bash cka-sim/scripts/test.sh
# CI: invoked by .github/workflows/validate.yml's bash-tests job (added in plan 02-05).

set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "cka-sim test"

info "step 1: lint trap catalog"
"$CKA_SIM_ROOT/scripts/lint-traps.sh"
ok "catalog lint passed"

info "step 2: lint packs"
"$CKA_SIM_ROOT/scripts/lint-packs.sh"
ok "pack lint passed"

info "step 3: lint coverage"
"$CKA_SIM_ROOT/scripts/lint-coverage.sh"
ok "coverage lint passed"

info "step 4: lint trap coverage"
"$CKA_SIM_ROOT/scripts/lint-trap-coverage.sh"
ok "trap-coverage lint passed"

info "step 5: lint deprecated strings"
"$CKA_SIM_ROOT/scripts/lint-deprecated-strings.sh"
ok "deprecated-strings lint passed"

info "step 6: run bash unit cases"
"$CKA_SIM_ROOT/tests/run.sh"
ok "all unit cases passed"

info "step 7: lint question symptom (live-cluster gated)"
"$CKA_SIM_ROOT/scripts/lint-question-symptom.sh"
ok "symptom-diff lint passed (or skipped — see above)"

ok "test.sh complete"
