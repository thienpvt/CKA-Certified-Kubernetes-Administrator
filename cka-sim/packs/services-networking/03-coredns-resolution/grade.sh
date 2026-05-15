#!/bin/bash
# Phase 07.1 AUDIT-01 — services-networking/03-coredns-resolution/grade.sh
# Risk: HIGH — pod exists + dnsPolicy=None are setup-owned (setup creates pod with
# dnsPolicy=None pointing at 1.1.1.1). Candidate must delete+recreate pod with
# correct kube-dns nameserver. Fix: gate pod existence on assert_changed_since_setup;
# gate dnsPolicy + nslookup assertions on candidate_modified flag.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertion 1: pod modified since setup (candidate recreated with correct DNS config)
cka_sim::grade::assert_changed_since_setup pod q03-dnsclient -n "$CKA_SIM_LAB_NS"

# Track candidate modification for downstream gating
pod_modified=0
if cka_sim::baseline::is_candidate_modified pod q03-dnsclient -n "$CKA_SIM_LAB_NS"; then
  pod_modified=1
fi

# Assertion 2: dnsPolicy=None (gated — must come from candidate-authored pod, not setup)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if (( pod_modified == 1 )); then
  actual_policy=$(kubectl get pod q03-dnsclient -n "$CKA_SIM_LAB_NS" -o jsonpath='{.spec.dnsPolicy}' 2>/dev/null)
  if [[ "$actual_policy" == "None" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
    CKA_SIM_GRADE_PASSES+=("pod q03-dnsclient dnsPolicy=None (candidate-authored)")
    ok "pod q03-dnsclient dnsPolicy=None (candidate-authored)"
  else
    CKA_SIM_GRADE_FAILS+=("pod q03-dnsclient dnsPolicy='$actual_policy' (expected 'None')")
    err "pod q03-dnsclient dnsPolicy='$actual_policy' (expected 'None')"
  fi
else
  CKA_SIM_GRADE_FAILS+=("pod q03-dnsclient dnsPolicy check skipped — pod not modified by candidate")
  err "pod q03-dnsclient dnsPolicy check skipped — pod not modified by candidate"
fi

# Assertion 3: DNS resolution succeeds (gated — only meaningful for candidate-authored pod)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if (( pod_modified == 1 )); then
  out=$(kubectl exec -n "$CKA_SIM_LAB_NS" q03-dnsclient -- nslookup kubernetes.default.svc.cluster.local 2>&1)
  rc=$?
  if [[ $rc -eq 0 && "$out" == *"Address"* ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
    CKA_SIM_GRADE_PASSES+=("q03-dnsclient resolves kubernetes.default.svc.cluster.local")
    ok "q03-dnsclient resolves kubernetes.default.svc.cluster.local"
  else
    CKA_SIM_GRADE_FAILS+=("q03-dnsclient cannot resolve kubernetes.default.svc.cluster.local")
    err "q03-dnsclient cannot resolve kubernetes.default.svc.cluster.local"
    cka_sim::grade::record_trap coredns-forward-to-invalid-upstream
  fi
else
  CKA_SIM_GRADE_FAILS+=("DNS resolution check skipped — pod not modified by candidate")
  err "DNS resolution check skipped — pod not modified by candidate"
fi

cka_sim::grade::emit_result
