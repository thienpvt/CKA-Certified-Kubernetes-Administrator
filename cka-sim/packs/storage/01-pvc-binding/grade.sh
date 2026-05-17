#!/bin/bash
# storage/01-pvc-binding/grade.sh
# Phase 07.1 D-25 — switched from assert_changed_since_setup (rv-based, unreliable
# for PVs where binding controller increments rv post-setup) to deterministic
# field check. PV with no nodeAffinity → empty jsonpath result → fail.
# Phase 10 BUG-H01 — score the actual symptom (Pod scheduling) and the full nodeAffinity shape.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Phase 10 BUG-H01 — score the actual symptom (Pod scheduling) and the full nodeAffinity shape.

# Precondition (weight=0): PVC must be Bound — informational only.
# Setup's PV+PVC pair binds automatically at creation; nodeAffinity only matters at Pod scheduling.
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" "app-data" 0

# Precondition (weight=0): consumer Pod must be Ready — informational only.
# Defence-in-depth wait: nudge the apiserver to surface the latest scheduling state
# before the assertion. Non-fatal — empty submission Pod stays Pending and that's
# what we want to surface to the candidate. `|| true` keeps the grader running.
kubectl wait --for=condition=Ready pod/q01-app-consumer \
  -n "$CKA_SIM_LAB_NS" --timeout=10s >/dev/null 2>&1 || true
cka_sim::grade::assert_pod_ready "$CKA_SIM_LAB_NS" "q01-app-consumer" 0

# Scoring assertion 1 (weight=1): PV nodeAffinity matchExpressions key.
# Setup creates PV WITHOUT nodeAffinity (the trap) → field is empty → FAIL on empty submission.
# Candidate must add nodeAffinity → field matches → PASS.
cka_sim::grade::assert_field_eq pv q01-app-pv \
  '{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].key}' \
  'kubernetes.io/hostname'

# Scoring assertion 2 (weight=1): PV nodeAffinity matchExpressions operator.
# Grades that the candidate authored a complete, valid matchExpression — not just a key string.
# ref-solution.sh patches operator: Exists, so this is the canonical answer shape.
cka_sim::grade::assert_field_eq pv q01-app-pv \
  '{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].operator}' \
  'Exists'

# Scoring assertion 3 (weight=1): PV has nodeAffinity.required.nodeSelectorTerms (presence).
# Catches a candidate who wrote `preferred` instead of `required` (still satisfies
# key/operator on a different jsonpath but is not a HARD requirement — won't fix the
# scheduling failure). Inline accumulator increment — pattern from
# cka-sim/packs/services-networking/05-kube-proxy-mode/grade.sh:22-31.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
required_terms=$(kubectl get pv q01-app-pv \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[*].matchExpressions[*].key}' 2>/dev/null || true)
if [[ -n "$required_terms" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("PV q01-app-pv has nodeAffinity.required.nodeSelectorTerms")
  ok "PV q01-app-pv has nodeAffinity.required.nodeSelectorTerms"
else
  CKA_SIM_GRADE_FAILS+=("PV q01-app-pv has no nodeAffinity.required.nodeSelectorTerms")
  err "PV q01-app-pv has no nodeAffinity.required.nodeSelectorTerms"
fi

# Trap detector: if PV still has hostPath but no nodeAffinity, record the seeded trap.
tid=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity q01-app-pv)
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

# Finalize — prints SCORE + Trap N: lines to stdout.
cka_sim::grade::emit_result
