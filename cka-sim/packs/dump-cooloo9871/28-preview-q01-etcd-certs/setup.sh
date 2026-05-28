#!/bin/bash
set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
export CKA_SIM_PACK=dump-cooloo9871
export CKA_SIM_QUESTION_ID=dump-q28-etcd-certs
# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"
# shellcheck source=../_dump_lib.sh disable=SC1091
source "$(dirname "$0")/../_dump_lib.sh"
cka_sim::dump::setup "28"
