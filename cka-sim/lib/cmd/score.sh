#!/bin/bash
# cka-sim score — view a past session report (Phase 1: stub, Phase 7: implementation)

set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

err "score — not implemented yet (phase 7)"
exit 2
