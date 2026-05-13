#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"
source "$CKA_SIM_ROOT/lib/traps.sh"

sandbox="/tmp/q04-pss-enforce"
log_file="$sandbox/violator-admission.log"
candidate_file="$sandbox/candidate-violator.yaml"

# Defence-in-depth wait: setup already waited but a rapid reset->setup->grade
# loop may still be mid-roll. `|| true` keeps this non-fatal — the
# readyReplicas assertion below is the authoritative check.
kubectl wait --for=condition=Available deployment/q04-compliant \
  -n "$CKA_SIM_LAB_NS" --timeout=30s >/dev/null 2>&1 || true

# Assertions 1 & 2 — namespace PSS labels.
cka_sim::grade::assert_field_eq namespace "$CKA_SIM_LAB_NS" \
  '{.metadata.labels.pod-security\.kubernetes\.io/enforce}' restricted
cka_sim::grade::assert_field_eq namespace "$CKA_SIM_LAB_NS" \
  '{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}' v1.35

# Assertion 3 — admission log carries v1.25+ PSS violation wording.
# Accepts both `violates PodSecurity` (Pod rejection) and `would violate
# PodSecurity` (Deployment Warning) for defence-in-depth. The admission log
# is setup-owned evidence; no trap is recorded from this assertion's miss.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if grep -qE '(would violate|violates) PodSecurity "(privileged|baseline|restricted):(v1\.[0-9]+|latest)":' "$log_file" 2>/dev/null; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "admission log uses v1.25+ PodSecurity wording"
else
  CKA_SIM_GRADE_FAILS+=("admission log missing expected PodSecurity wording")
  err "admission log missing expected PodSecurity wording"
fi

# Assertion 4 — q04-compliant Deployment exists.
cka_sim::grade::assert_resource_exists deployment q04-compliant -n "$CKA_SIM_LAB_NS"

# Assertion 5 — q04-compliant has at least one ready replica.
ready=$(kubectl get deployment q04-compliant -n "$CKA_SIM_LAB_NS" \
          -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "${ready:-0}" =~ ^[1-9][0-9]*$ ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "q04-compliant has ready replicas"
else
  CKA_SIM_GRADE_FAILS+=("q04-compliant has no ready replicas")
  err "q04-compliant has no ready replicas"
fi

# Trap detection — route through lib/traps.sh detectors. Single source of
# truth for the two declared traps; no inline greps. Detectors operate on
# raw candidate YAML text (no kubectl call) so they cost nothing.
cand_content=""
[[ -r "$candidate_file" ]] && cand_content=$(cat "$candidate_file")

hit=$(cka_sim::trap::detect_pss_error_string_mismatch "$cand_content")
[[ -n "$hit" ]] && cka_sim::grade::record_trap "$hit"

hit=$(cka_sim::trap::detect_psp_fictional_pod_label_exemption "$cand_content")
[[ -n "$hit" ]] && cka_sim::grade::record_trap "$hit"

cka_sim::grade::emit_result
