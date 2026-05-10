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

info "step 3: run bash unit cases"
"$CKA_SIM_ROOT/tests/run.sh"
ok "all unit cases passed"

ok "test.sh complete"
