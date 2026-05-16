#!/bin/bash
# storage/01-pvc-binding/grade.sh
# Phase 07.1 D-25 — switched from assert_changed_since_setup (rv-based, unreliable
# for PVs where binding controller increments rv post-setup) to deterministic
# field check. PV with no nodeAffinity → empty jsonpath result → fail.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Precondition (weight=0): PVC must be Bound — informational only.
# Setup's PV+PVC pair binds automatically at creation; nodeAffinity only matters at Pod scheduling.
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" "app-data" 0

# Scoring assertion: PV must have nodeAffinity expression key kubernetes.io/hostname.
# Setup creates PV WITHOUT nodeAffinity (the trap) → field is empty → FAIL on empty submission.
# Candidate must add nodeAffinity → field matches → PASS.
cka_sim::grade::assert_field_eq pv q01-app-pv \
  '{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].key}' \
  'kubernetes.io/hostname'

# Trap detector: if PV still has hostPath but no nodeAffinity, record the seeded trap.
tid=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity q01-app-pv)
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

# Finalize — prints SCORE + Trap N: lines to stdout.
cka_sim::grade::emit_result
