#!/bin/bash
# workloads-scheduling/01-deployment-requests/grade.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Wait up to 60s for the Deployment to be Available before reading pod state (RESEARCH Assumption A4).
kubectl wait --for=condition=Available deployment/load-app -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true

# Assertion 1: deployment exists
cka_sim::grade::assert_resource_exists deployment load-app -n "$CKA_SIM_LAB_NS"

# Assertion 2: deployment uses dedicated SA "load-app-sa"
cka_sim::grade::assert_field_eq deployment load-app \
  '{.spec.template.spec.serviceAccountName}' \
  'load-app-sa' \
  -n "$CKA_SIM_LAB_NS"

# Assertion 3: container has resources.requests.cpu == 50m
cka_sim::grade::assert_field_eq deployment load-app \
  '{.spec.template.spec.containers[0].resources.requests.cpu}' \
  '50m' \
  -n "$CKA_SIM_LAB_NS"

# Assertion 4: container has resources.requests.memory == 64Mi
cka_sim::grade::assert_field_eq deployment load-app \
  '{.spec.template.spec.containers[0].resources.requests.memory}' \
  '64Mi' \
  -n "$CKA_SIM_LAB_NS"

# Trap detector: probe the deployment's first running pod for default-sa-used.
pod=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=load-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$pod" ]]; then
  tid=$(cka_sim::trap::detect_default_sa_used "$CKA_SIM_LAB_NS" "$pod")
  [[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
fi

cka_sim::grade::emit_result
