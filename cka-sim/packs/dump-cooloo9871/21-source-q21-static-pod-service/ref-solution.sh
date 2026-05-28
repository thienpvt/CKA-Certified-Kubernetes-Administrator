#!/bin/bash
set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
# shellcheck source=../_dump_lib.sh disable=SC1091
source "$(dirname "$0")/../_dump_lib.sh"
cka_sim::dump::ref_solution "21"
