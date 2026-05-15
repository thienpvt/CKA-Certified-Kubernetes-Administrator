#!/bin/bash
# workloads-scheduling/02-rolling-update-rollback/grade.sh
# Read-only grader: candidate must roll forward AND roll back (generation delta >= 2).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# ---------- Phase 07.1 D-13 ----------
# Score only the candidate-driven generation delta; preconditions are weight-0
# informational checks that provide diagnostic messages but award no points.
# Empty submission scores 0/1; ref-solution (rollout-forward + undo) scores 1/1.

# Precondition 1 (weight=0): Deployment exists — informational only.
cka_sim::grade::assert_resource_exists deployment web -n "$CKA_SIM_LAB_NS" 0

# Precondition 2 (weight=0): rollout has completed — informational diagnostic.
if kubectl rollout status deployment/web -n "$CKA_SIM_LAB_NS" --timeout=60s >/dev/null 2>&1; then
  ok "rollout status succeeded for deployment/web"
else
  err "rollout status did not complete for deployment/web"
fi

# Scoring assertion: generation delta >= 2 proves candidate executed at least
# one rollout-forward (gen+1) AND one rollout-undo (gen+1).
cka_sim::grade::assert_generation_delta_ge deployment web 2 -n "$CKA_SIM_LAB_NS"

# Trap detector: default-sa-used on the first running pod of the Deployment.
pod=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=web -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$pod" ]]; then
  tid=$(cka_sim::trap::detect_default_sa_used "$CKA_SIM_LAB_NS" "$pod")
  [[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
fi

cka_sim::grade::emit_result
