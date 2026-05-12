#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

cka_sim::grade::assert_resource_exists pod q03-dnsclient -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_field_eq pod q03-dnsclient '{.spec.dnsPolicy}' 'None' -n "$CKA_SIM_LAB_NS"

out=$(kubectl exec -n "$CKA_SIM_LAB_NS" q03-dnsclient -- nslookup kubernetes.default.svc.cluster.local 2>&1)
rc=$?
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ $rc -eq 0 && "$out" == *"Address"* ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("q03-dnsclient resolves kubernetes.default.svc.cluster.local")
  ok "q03-dnsclient resolves kubernetes.default.svc.cluster.local"
else
  CKA_SIM_GRADE_FAILS+=("q03-dnsclient cannot resolve kubernetes.default.svc.cluster.local")
  err "q03-dnsclient cannot resolve kubernetes.default.svc.cluster.local"
  cka_sim::grade::record_trap coredns-forward-to-invalid-upstream
fi

cka_sim::grade::emit_result
