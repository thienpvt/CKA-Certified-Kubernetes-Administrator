#!/bin/bash
# troubleshooting/02-netpol-dns-egress/grade.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

ns="$CKA_SIM_LAB_NS"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=web -n "$ns" --timeout=30s 2>/dev/null || true

web_pod=$(kubectl get pods -n "$ns" -l app.kubernetes.io/name=web -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

cka_sim::grade::assert_resource_exists networkpolicy default-deny-egress -n "$ns"
cka_sim::grade::assert_resource_exists networkpolicy allow-web-to-api -n "$ns"
cka_sim::grade::assert_resource_exists service api-svc -n "$ns"

if [[ -n "$web_pod" ]]; then
  cka_sim::grade::assert_pod_ready "$ns" "$web_pod"

  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
  if kubectl exec -n "$ns" "$web_pod" -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
    CKA_SIM_GRADE_PASSES+=("DNS resolves from web pod")
    ok "DNS resolves from web pod"
  else
    CKA_SIM_GRADE_FAILS+=("DNS resolution from web pod failed")
    err "DNS resolution from web pod failed"
    cka_sim::grade::record_trap missing-dns-egress
  fi

  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
  if kubectl exec -n "$ns" "$web_pod" -- timeout 5 bash -c 'echo > /dev/tcp/api-svc/8080' 2>/dev/null; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
    CKA_SIM_GRADE_PASSES+=("api-svc:8080 reachable from web pod")
    ok "api-svc:8080 reachable from web pod"
  else
    CKA_SIM_GRADE_FAILS+=("api-svc:8080 unreachable from web pod")
    err "api-svc:8080 unreachable from web pod"
    cka_sim::grade::record_trap netpol-default-deny-missing-allow
  fi
fi

selector_json=$(kubectl get networkpolicy allow-web-to-api -n "$ns" -o jsonpath='{.spec.podSelector.matchLabels}' 2>/dev/null || echo "")
if [[ "$selector_json" == *'"app":"web"'* && "$selector_json" != *"app.kubernetes.io/name"* ]]; then
  cka_sim::grade::record_trap netpol-label-key-drift
fi

cka_sim::grade::emit_result
