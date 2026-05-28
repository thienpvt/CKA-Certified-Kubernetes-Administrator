#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
CKA_SIM_DUMP_TRAP_ID="default-sa-used"
# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"
# shellcheck source=../_dump_lib.sh disable=SC1091
source "$(dirname "$0")/../_dump_lib.sh"
if [[ "${CKA_SIM_DUMP_FORCE_TRAP:-}" == "1" ]]; then
  cka_sim::grade::record_trap "$CKA_SIM_DUMP_TRAP_ID"
fi
cka_sim::dump::grade "13" "$CKA_SIM_DUMP_TRAP_ID"
