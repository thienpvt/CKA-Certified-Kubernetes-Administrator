#!/bin/bash
# workloads-scheduling/04-hpa-metrics-server/grade.sh — read-only grader.
# Assertions:
#   1. HPA q04-load exists in lab ns
#   2. minReplicas == 1
#   3. maxReplicas == 5
#   4. spec.metrics[type=Resource].resource.name == cpu
#   5. Behavioural: kubectl top pod returns readings (metrics-server alive)
# Trap: hpa-missing-metrics-server when AbleToScale condition reason == FailedGetResourceMetric.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertion 1: HPA exists.
cka_sim::grade::assert_resource_exists hpa q04-load -n "$CKA_SIM_LAB_NS"

# Assertion 2: minReplicas == 1.
cka_sim::grade::assert_field_eq hpa q04-load \
  '{.spec.minReplicas}' '1' -n "$CKA_SIM_LAB_NS"

# Assertion 3: maxReplicas == 5.
cka_sim::grade::assert_field_eq hpa q04-load \
  '{.spec.maxReplicas}' '5' -n "$CKA_SIM_LAB_NS"

# Assertion 4: CPU Resource metric present.
cka_sim::grade::assert_field_eq hpa q04-load \
  '{.spec.metrics[?(@.type=="Resource")].resource.name}' 'cpu' -n "$CKA_SIM_LAB_NS"

# Assertion 5: behavioural — metrics-server returns pod readings.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl top pod -n "$CKA_SIM_LAB_NS" -l app=q04-load >/dev/null 2>&1; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("kubectl top pod returns readings (metrics-server alive)")
  ok "kubectl top pod returns readings (metrics-server alive)"
else
  CKA_SIM_GRADE_FAILS+=("kubectl top pod failed (metrics-server unreachable or not installed)")
  err "kubectl top pod failed (metrics-server unreachable or not installed)"
fi

# Trap detector: HPA condition AbleToScale=False with reason FailedGetResourceMetric.
reason=$(kubectl get hpa q04-load -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].reason}' 2>/dev/null || echo "")
if [[ "$reason" == "FailedGetResourceMetric" ]]; then
  cka_sim::grade::record_trap hpa-missing-metrics-server
fi

cka_sim::grade::emit_result
