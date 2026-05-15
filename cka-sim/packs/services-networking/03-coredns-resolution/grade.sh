#!/bin/bash
# Phase 07.1 AUDIT-01 — services-networking/03-coredns-resolution/grade.sh
# Risk: HIGH — pod exists + dnsPolicy=None are setup-owned (setup creates pod with
# dnsPolicy=None pointing at 1.1.1.1). Candidate must delete+recreate pod with
# correct kube-dns nameserver. Fix: gate pod existence on assert_changed_since_setup.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertion 1: pod modified since setup (candidate recreated with correct DNS config)
cka_sim::grade::assert_changed_since_setup pod q03-dnsclient -n "$CKA_SIM_LAB_NS"

# Assertion 2: dnsPolicy is None
cka_sim::grade::assert_field_eq pod q03-dnsclient '{.spec.dnsPolicy}' 'None' -n "$CKA_SIM_LAB_NS"

# Assertion 3: DNS resolution succeeds
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
