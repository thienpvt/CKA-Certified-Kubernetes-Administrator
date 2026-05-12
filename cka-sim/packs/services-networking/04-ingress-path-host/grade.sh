#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

cka_sim::grade::assert_resource_exists ingress q04-web -n "$CKA_SIM_LAB_NS"

ic=$(kubectl get ingress q04-web -n "$CKA_SIM_LAB_NS" -o jsonpath='{.spec.ingressClassName}' 2>/dev/null || true)
ann=$(kubectl get ingress q04-web -n "$CKA_SIM_LAB_NS" -o jsonpath='{.metadata.annotations.kubernetes\.io/ingress\.class}' 2>/dev/null || true)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$ic" == "q04-nginx" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("ingress q04-web uses ingressClassName q04-nginx")
  ok "ingress q04-web uses ingressClassName q04-nginx"
else
  CKA_SIM_GRADE_FAILS+=("ingress q04-web missing ingressClassName q04-nginx")
  err "ingress q04-web missing ingressClassName q04-nginx"
  [[ -z "$ic" && -z "$ann" ]] && cka_sim::grade::record_trap ingress-missing-ingressclass
fi

cka_sim::grade::assert_field_eq ingress q04-web '{.spec.rules[0].host}' 'api.example.local' -n "$CKA_SIM_LAB_NS"

path=$(kubectl get ingress q04-web -n "$CKA_SIM_LAB_NS" -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null || true)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$path" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("ingress q04-web has a path rule")
  ok "ingress q04-web has a path rule"
else
  CKA_SIM_GRADE_FAILS+=("ingress q04-web missing path rule")
  err "ingress q04-web missing path rule"
fi

cka_sim::grade::assert_field_eq ingress q04-web '{.spec.rules[0].http.paths[0].backend.service.name}' 'q04-web' -n "$CKA_SIM_LAB_NS"

cka_sim::grade::emit_result
