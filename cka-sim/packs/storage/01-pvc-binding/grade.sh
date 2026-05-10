#!/bin/bash
# storage/01-pvc-binding/grade.sh — asserts PVC bound + PV has nodeAffinity; records trap if seeded condition still present.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertion 1: PVC must be Bound
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" "app-data"

# Assertion 2: PV must have nodeAffinity expression key kubernetes.io/hostname
cka_sim::grade::assert_field_eq pv q01-app-pv \
  '{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].key}' \
  'kubernetes.io/hostname'

# Trap detector: if PV still has hostPath but no nodeAffinity, record the seeded trap.
tid=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity q01-app-pv)
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

# Finalize — prints SCORE + Trap N: lines to stdout.
cka_sim::grade::emit_result
