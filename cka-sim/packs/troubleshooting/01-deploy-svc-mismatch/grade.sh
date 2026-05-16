#!/bin/bash
# troubleshooting/01-deploy-svc-mismatch/grade.sh
# Phase 07.1 AUDIT-01 — setup-collision: deployment/web + service/web-svc both authored by setup.sh
#   → assertions on existence demoted to weight=0; behavioural endpoints_nonempty already gated on candidate fix.
# Read-only grader. `set -uo` (not -euo) so failed assertions accumulate per D-05/D-06.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Settle time for Endpoints controller (briefly — grade.sh is a snapshot check).
kubectl wait --for=condition=Available deployment/web -n "$CKA_SIM_LAB_NS" --timeout=30s 2>/dev/null || true

# Phase 07.1 AUDIT-01: demoted to weight=0 — setup.sh creates deployment/web AND service/web-svc.
cka_sim::grade::assert_resource_exists deployment web -n "$CKA_SIM_LAB_NS" 0
cka_sim::grade::assert_resource_exists service web-svc -n "$CKA_SIM_LAB_NS" 0

# Core assertion: Service endpoints must be non-empty for the Service to route traffic.
# This is the single check that flips from fail (under trap) to pass (under fix).
# CORRECT BY DESIGN: setup leaves selector=app=webserver, so endpoints stay empty until candidate fixes.
cka_sim::grade::assert_endpoints_nonempty "$CKA_SIM_LAB_NS" "web-svc"

# Trap detector: Service.spec.selector matches no pod (or endpoints empty despite pods).
tid=$(cka_sim::trap::detect_service_label_mismatch "$CKA_SIM_LAB_NS" "web-svc")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

# Trap detector: canary workload is stuck on a non-existent image tag.
canary_reasons=$(kubectl get pods -n "$CKA_SIM_LAB_NS" -l app=web-canary -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null || echo "")
if [[ " $canary_reasons " == *" ImagePullBackOff "* || " $canary_reasons " == *" ErrImagePull "* ]]; then
  cka_sim::grade::record_trap imagepullbackoff-wrong-tag
fi

cka_sim::grade::emit_result
