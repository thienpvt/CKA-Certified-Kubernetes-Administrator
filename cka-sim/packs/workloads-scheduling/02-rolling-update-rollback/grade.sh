#!/bin/bash
# workloads-scheduling/02-rolling-update-rollback/grade.sh
# Read-only grader: rollout succeeded + final image back at nginx:1.25 + generation bumped twice.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertion 1: Deployment exists.
cka_sim::grade::assert_resource_exists deployment web -n "$CKA_SIM_LAB_NS"

# Assertion 2: rollout has completed (behavioural — no grep, uses kubectl native exit code).
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl rollout status deployment/web -n "$CKA_SIM_LAB_NS" --timeout=60s >/dev/null 2>&1; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("rollout status succeeded for deployment/web")
  ok "rollout status succeeded for deployment/web"
else
  CKA_SIM_GRADE_FAILS+=("rollout status did not complete for deployment/web")
  err "rollout status did not complete for deployment/web"
fi

# Assertion 3: final image is nginx:1.25 (proves rollback happened).
cka_sim::grade::assert_field_eq deployment web \
  '{.spec.template.spec.containers[0].image}' \
  'nginx:1.25' \
  -n "$CKA_SIM_LAB_NS"

# Assertion 4: deployment .metadata.generation >= 3 (setup did 2 generation bumps;
# candidate's rollout-forward + rollout-undo must push this to >=3).
gen=$(kubectl get deployment web -n "$CKA_SIM_LAB_NS" -o jsonpath='{.metadata.generation}' 2>/dev/null || echo "0")
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$gen" =~ ^[0-9]+$ ]] && (( gen >= 3 )); then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("deployment generation = $gen (>=3 proves rollout + rollback happened)")
  ok "deployment generation = $gen (>=3 proves rollout + rollback happened)"
else
  CKA_SIM_GRADE_FAILS+=("deployment generation = '$gen' (expected >=3)")
  err "deployment generation = '$gen' (expected >=3)"
fi

# Trap detector: default-sa-used on the first running pod of the Deployment.
pod=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=web -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$pod" ]]; then
  tid=$(cka_sim::trap::detect_default_sa_used "$CKA_SIM_LAB_NS" "$pod")
  [[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
fi

cka_sim::grade::emit_result
