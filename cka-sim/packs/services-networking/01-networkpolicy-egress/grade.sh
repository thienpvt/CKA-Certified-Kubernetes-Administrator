#!/bin/bash
# Phase 07.1 AUDIT-01 — services-networking/01-networkpolicy-egress/grade.sh
# Risk: HIGH — NP exists + pod Ready are setup-owned; DNS resolution depends on NP fix.
# Fix: gate NP assertion on assert_changed_since_setup (candidate must modify the NP);
#      gate DNS resolution on NP being candidate-modified.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Wait briefly for pod readiness (best-effort; subsequent checks tolerate not-Ready)
kubectl wait --for=condition=Ready pod/probe -n "$CKA_SIM_LAB_NS" --timeout=30s 2>/dev/null || true

# Assertion 1: NetworkPolicy has been modified since setup (candidate added DNS egress rule)
cka_sim::grade::assert_changed_since_setup networkpolicy egress-restrict -n "$CKA_SIM_LAB_NS"

# Track whether NP was modified — gate behavioural check on this
np_modified=0
if cka_sim::baseline::is_candidate_modified networkpolicy egress-restrict -n "$CKA_SIM_LAB_NS"; then
  np_modified=1
fi

# Assertion 2: probe pod Ready
cka_sim::grade::assert_pod_ready "$CKA_SIM_LAB_NS" "probe"

# Assertion 3: DNS resolution works in-pod (gated on candidate-modified NP)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if (( np_modified == 1 )); then
  if kubectl exec -n "$CKA_SIM_LAB_NS" probe -- nslookup kubernetes.default >/dev/null 2>&1; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
    CKA_SIM_GRADE_PASSES+=("DNS resolution from pod 'probe' works")
    ok "DNS resolution from pod 'probe' works"
  else
    CKA_SIM_GRADE_FAILS+=("DNS resolution from pod 'probe' failed (nslookup kubernetes.default)")
    err "DNS resolution from pod 'probe' failed (nslookup kubernetes.default)"
  fi
else
  CKA_SIM_GRADE_FAILS+=("DNS resolution skipped — NetworkPolicy not modified by candidate")
  err "DNS resolution skipped — NetworkPolicy not modified by candidate"
fi

# Trap detector: NetworkPolicy egress restricted but no DNS allow.
tid=$(cka_sim::trap::detect_missing_dns_egress "$CKA_SIM_LAB_NS" "egress-restrict")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

cka_sim::grade::emit_result
