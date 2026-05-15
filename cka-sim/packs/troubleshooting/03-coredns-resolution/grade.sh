#!/bin/bash
# troubleshooting/03-coredns-resolution/grade.sh
# Phase 07.1 AUDIT-01 — setup-collision: ConfigMap + Deployment + Service + Pod (with dnsPolicy=None) all authored by setup.sh.
#   → existence/field assertions demoted to weight=0; added assert_changed_since_setup on ConfigMap (rv-only signal per RESEARCH Q1).
#   → DNS-resolution behavioural checks already gated (invalid upstream + bad subPath; correctly fail until candidate fixes).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

ns="$CKA_SIM_LAB_NS"

kubectl wait --for=condition=Ready pod/q03-dnsclient -n "$ns" --timeout=30s 2>/dev/null || true

# Phase 07.1 AUDIT-01: demoted to weight=0 — all created by setup.sh.
cka_sim::grade::assert_resource_exists configmap q03-coredns-corefile -n "$ns" 0
cka_sim::grade::assert_resource_exists deployment q03-coredns -n "$ns" 0
cka_sim::grade::assert_resource_exists service q03-coredns -n "$ns" 0
cka_sim::grade::assert_resource_exists pod q03-dnsclient -n "$ns" 0
cka_sim::grade::assert_field_eq pod q03-dnsclient '{.spec.dnsPolicy}' 'None' -n "$ns" 0

# Phase 07.1 AUDIT-01: candidate must edit the Corefile ConfigMap (fix forward upstream).
# ConfigMaps don't bump generation (no .spec) — relies on rv-fallback in assert_changed_since_setup.
cka_sim::grade::assert_changed_since_setup configmap q03-coredns-corefile -n "$ns"

# Phase 07.1 AUDIT-01: candidate must also fix the broken volumeMount subPath on the Deployment.
cka_sim::grade::assert_changed_since_setup deployment q03-coredns -n "$ns"

out=$(kubectl exec -n "$ns" q03-dnsclient -- nslookup kubernetes.default.svc.cluster.local 2>&1)
rc=$?
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ $rc -eq 0 && "$out" == *"Address"* ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("q03-dnsclient resolves kubernetes.default.svc.cluster.local")
  ok "q03-dnsclient resolves kubernetes.default.svc.cluster.local"
else
  CKA_SIM_GRADE_FAILS+=("q03-dnsclient cannot resolve kubernetes.default.svc.cluster.local")
  err "q03-dnsclient cannot resolve kubernetes.default.svc.cluster.local"
fi

external_out=$(kubectl exec -n "$ns" q03-dnsclient -- nslookup www.example.com 2>&1)
external_rc=$?
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ $external_rc -eq 0 && "$external_out" == *"Address"* ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("q03-dnsclient resolves www.example.com")
  ok "q03-dnsclient resolves www.example.com"
else
  CKA_SIM_GRADE_FAILS+=("q03-dnsclient cannot resolve www.example.com")
  err "q03-dnsclient cannot resolve www.example.com"
  cka_sim::grade::record_trap coredns-forward-to-invalid-upstream
fi

corefile=$(kubectl get configmap q03-coredns-corefile -n "$ns" -o jsonpath='{.data.Corefile}' 2>/dev/null || true)
if [[ "$corefile" == *"203.0.113."* || "$corefile" == *"192.0.2."* || "$corefile" == *"198.51.100."* ]]; then
  cka_sim::grade::record_trap coredns-forward-to-invalid-upstream
fi

subpaths=$(kubectl get deploy q03-coredns -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].subPath}' 2>/dev/null || true)
if [[ "$subpaths" == *"corefile"* && "$subpaths" != *"Corefile"* ]]; then
  cka_sim::grade::record_trap coredns-sandbox-configmap-mount
fi

cka_sim::grade::emit_result
