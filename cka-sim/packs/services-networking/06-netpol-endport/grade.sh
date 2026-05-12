#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

kubectl wait --for=condition=Ready pod/q06-server -n "$CKA_SIM_LAB_NS" --timeout=30s 2>/dev/null || true
kubectl wait --for=condition=Ready pod/q06-client -n "$CKA_SIM_LAB_NS" --timeout=30s 2>/dev/null || true

cka_sim::grade::assert_resource_exists networkpolicy q06-allow-range -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_field_eq networkpolicy q06-allow-range '{.spec.ingress[0].ports[0].port}' '8080' -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_field_eq networkpolicy q06-allow-range '{.spec.ingress[0].ports[0].endPort}' '8090' -n "$CKA_SIM_LAB_NS"

proto=$(kubectl get networkpolicy q06-allow-range -n "$CKA_SIM_LAB_NS" -o jsonpath='{.spec.ingress[0].ports[0].protocol}' 2>/dev/null || true)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$proto" == "TCP" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("NetworkPolicy q06-allow-range declares protocol TCP")
  ok "NetworkPolicy q06-allow-range declares protocol TCP"
else
  CKA_SIM_GRADE_FAILS+=("NetworkPolicy q06-allow-range missing protocol TCP")
  err "NetworkPolicy q06-allow-range missing protocol TCP"
  cka_sim::grade::record_trap netpol-endport-missing-protocol
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl exec -n "$CKA_SIM_LAB_NS" q06-client -- wget -qO- --timeout=3 q06-server:8085 >/dev/null 2>&1; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("q06-client can reach q06-server:8085 inside allowed endPort range")
  ok "q06-client can reach q06-server:8085 inside allowed endPort range"
else
  CKA_SIM_GRADE_FAILS+=("q06-client cannot reach q06-server:8085 inside allowed endPort range")
  err "q06-client cannot reach q06-server:8085 inside allowed endPort range"
  cka_sim::grade::record_trap netpol-endport-missing-protocol
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl exec -n "$CKA_SIM_LAB_NS" q06-client -- wget -qO- --timeout=3 q06-server:8095 >/dev/null 2>&1; then
  CKA_SIM_GRADE_FAILS+=("q06-client can reach q06-server:8095 outside allowed endPort range")
  err "q06-client can reach q06-server:8095 outside allowed endPort range"
else
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("q06-client cannot reach q06-server:8095 outside allowed endPort range")
  ok "q06-client cannot reach q06-server:8095 outside allowed endPort range"
fi

cka_sim::grade::emit_result
