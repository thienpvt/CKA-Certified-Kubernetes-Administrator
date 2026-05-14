#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="troubleshooting"
CKA_SIM_QUESTION_ID="troubleshooting-debug-node"
sandbox="/tmp/q04-debug-node"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID" 120

worker=$(cka_sim::setup::read_node_worker)

mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"
: > "$sandbox/answer.txt"
printf '%s\n' "$worker" > "$sandbox/worker.txt"
