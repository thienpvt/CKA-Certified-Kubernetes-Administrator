#!/bin/bash
# Phase 07.1 AUDIT-01 — no leak (HPA is candidate-authored; setup only creates Deployment) → header added
# workloads-scheduling/04-hpa-metrics-server/grade.sh — read-only grader.
# Phase 13 BUG-M06 — added Assertions 5 and 6 to enforce target.type=Utilization
# and target.averageUtilization=50; the prior behavioural check renumbers to 7.
# Assertions:
#   1. HPA q04-load exists in lab ns (candidate-authored)
#   2. minReplicas == 1
#   3. maxReplicas == 5
#   4. spec.metrics[type=Resource].resource.name == cpu
#   5. spec.metrics[type=Resource].resource.target.type == Utilization
#   6. spec.metrics[type=Resource].resource.target.averageUtilization == 50
#   7. Behavioural: kubectl top pod returns readings (metrics-server alive)
# Trap: hpa-missing-metrics-server when AbleToScale condition reason == FailedGetResourceMetric.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertion 1: HPA exists (candidate-authored — not in setup baseline).
cka_sim::grade::assert_resource_candidate_authored hpa q04-load -n "$CKA_SIM_LAB_NS"

# Assertion 2: minReplicas == 1.
cka_sim::grade::assert_field_eq hpa q04-load \
  '{.spec.minReplicas}' '1' -n "$CKA_SIM_LAB_NS"

# Assertion 3: maxReplicas == 5.
cka_sim::grade::assert_field_eq hpa q04-load \
  '{.spec.maxReplicas}' '5' -n "$CKA_SIM_LAB_NS"

# Assertion 4: CPU Resource metric present.
cka_sim::grade::assert_field_eq hpa q04-load \
  '{.spec.metrics[?(@.type=="Resource")].resource.name}' 'cpu' -n "$CKA_SIM_LAB_NS"

# Assertion 5: target type is Utilization (not AverageValue / Value).
cka_sim::grade::assert_field_eq hpa q04-load \
  '{.spec.metrics[?(@.type=="Resource")].resource.target.type}' 'Utilization' -n "$CKA_SIM_LAB_NS"

# Assertion 6: target.averageUtilization == 50 (the question mandates 50%).
cka_sim::grade::assert_field_eq hpa q04-load \
  '{.spec.metrics[?(@.type=="Resource")].resource.target.averageUtilization}' '50' -n "$CKA_SIM_LAB_NS"

# Assertion 7: behavioural — metrics-server returns pod readings.
# metrics-server needs up to 60s after install for the first scrape to land.
# Phase 07.1 D-22 audit-escape: retries + sleep are env-overridable so kubectl-stub fixture
# tests don't pay the 60s wall-clock cost; defaults preserve production cluster behaviour.
# Phase 13 BUG-M10 — gate A7 on HPA q04-load existing AND being candidate-authored.
# Without this gate, any cluster with metrics-server alive grants 1 point on empty
# submissions because `kubectl top pod -l app=q04-load` returns readings against the
# setup-seeded Deployment regardless of candidate work — same class of grading-honesty
# leak Phase 07.1 closed.
#
# Note: is_candidate_modified returns 0 ("modified") when the resource is absent from
# baseline (setup doesn't create the HPA — that's the candidate's job). So we MUST also
# require the resource to exist. TOTAL is incremented unconditionally to keep the
# scoring denominator stable at 7 across all candidate paths.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl get hpa q04-load -n "$CKA_SIM_LAB_NS" >/dev/null 2>&1 \
   && cka_sim::baseline::is_candidate_modified hpa q04-load -n "$CKA_SIM_LAB_NS"; then
  top_ok=0
  retries="${CKA_SIM_GRADE_TOP_RETRIES:-12}"
  sleep_s="${CKA_SIM_GRADE_TOP_SLEEP:-5}"
  for i in $(seq 1 "$retries"); do
    if kubectl top pod -n "$CKA_SIM_LAB_NS" -l app=q04-load >/dev/null 2>&1; then
      top_ok=1
      break
    fi
    sleep "$sleep_s"
  done
  if (( top_ok == 1 )); then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
    CKA_SIM_GRADE_PASSES+=("kubectl top pod returns readings (metrics-server alive)")
    ok "kubectl top pod returns readings (metrics-server alive)"
  else
    CKA_SIM_GRADE_FAILS+=("kubectl top pod failed (metrics-server unreachable or not installed)")
    err "kubectl top pod failed (metrics-server unreachable or not installed)"
  fi
else
  CKA_SIM_GRADE_FAILS+=("metrics-server probe skipped (HPA q04-load not candidate-authored)")
  err "metrics-server probe skipped (HPA q04-load not candidate-authored)"
fi

# Trap detector: HPA condition AbleToScale=False with reason FailedGetResourceMetric.
reason=$(kubectl get hpa q04-load -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].reason}' 2>/dev/null || echo "")
if [[ "$reason" == "FailedGetResourceMetric" ]]; then
  cka_sim::grade::record_trap hpa-missing-metrics-server
fi

cka_sim::grade::emit_result
