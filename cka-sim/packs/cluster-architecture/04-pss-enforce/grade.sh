#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

sandbox="/tmp/q04-pss-enforce"
log_file="$sandbox/violator-admission.log"

cka_sim::grade::assert_field_eq namespace "$CKA_SIM_LAB_NS" '{.metadata.labels.pod-security\.kubernetes\.io/enforce}' restricted
cka_sim::grade::assert_field_eq namespace "$CKA_SIM_LAB_NS" '{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}' v1.35

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if grep -qE 'violates PodSecurity "(privileged|baseline|restricted):(v1\.[0-9]+|latest)":' "$log_file" 2>/dev/null; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "admission log uses v1.25+ PodSecurity wording"
else
  CKA_SIM_GRADE_FAILS+=("admission log missing expected PodSecurity wording")
  err "admission log missing expected PodSecurity wording"
fi

legacy_psp="PodSecurity""Policy"
if grep -qE "\b${legacy_psp}\b" "$log_file" 2>/dev/null; then
  cka_sim::grade::record_trap pss-error-string-mismatch
fi

if grep -qE 'pod-security\.kubernetes\.io/.*exempt' "$sandbox"/*.yaml 2>/dev/null; then
  cka_sim::grade::record_trap psp-fictional-pod-label-exemption
fi

cka_sim::grade::assert_resource_exists deployment q04-compliant -n "$CKA_SIM_LAB_NS"
ready=$(kubectl get deployment q04-compliant -n "$CKA_SIM_LAB_NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "${ready:-0}" =~ ^[1-9][0-9]*$ ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "q04-compliant has ready replicas"
else
  CKA_SIM_GRADE_FAILS+=("q04-compliant has no ready replicas")
  err "q04-compliant has no ready replicas"
fi

cka_sim::grade::emit_result
