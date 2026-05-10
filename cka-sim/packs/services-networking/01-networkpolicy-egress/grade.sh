#!/bin/bash
# services-networking/01-networkpolicy-egress/grade.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Wait briefly for pod readiness (best-effort; subsequent checks tolerate not-Ready)
kubectl wait --for=condition=Ready pod/probe -n "$CKA_SIM_LAB_NS" --timeout=30s 2>/dev/null || true

# Assertion 1: NetworkPolicy exists
cka_sim::grade::assert_resource_exists networkpolicy egress-restrict -n "$CKA_SIM_LAB_NS"

# Assertion 2: probe pod Ready
cka_sim::grade::assert_pod_ready "$CKA_SIM_LAB_NS" "probe"

# Assertion 3: DNS resolution works in-pod.
# Custom nslookup probe — the generic /dev/tcp egress helper is TCP-only, so UDP/53 DNS
# probing goes through kubectl exec nslookup per RESEARCH Pattern 5 footnote.
# Manual increment + named pass/fail message to mirror the helper contract.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl exec -n "$CKA_SIM_LAB_NS" probe -- nslookup kubernetes.default >/dev/null 2>&1; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("DNS resolution from pod 'probe' works")
  ok "DNS resolution from pod 'probe' works"
else
  CKA_SIM_GRADE_FAILS+=("DNS resolution from pod 'probe' failed (nslookup kubernetes.default)")
  err "DNS resolution from pod 'probe' failed (nslookup kubernetes.default)"
fi

# Trap detector: NetworkPolicy egress restricted but no DNS allow.
tid=$(cka_sim::trap::detect_missing_dns_egress "$CKA_SIM_LAB_NS" "egress-restrict")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

cka_sim::grade::emit_result
