#!/bin/bash
# Phase 07.1 D-16 / D-22: this question's grader is structurally thin —
# 5 preconditions are setup-state (weight=0); 1 scoring assertion checks the
# candidate-authored Pod q04-candidate. Flagged for v1.x rebuild in 07.1-VERIFICATION.md.
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

# ---------- Preconditions (setup-state; weight=0 — no scoring points) ----------

# Assertions 1 & 2 — namespace PSS labels (setup-applied).
cka_sim::grade::assert_field_eq namespace "$CKA_SIM_LAB_NS" \
  '{.metadata.labels.pod-security\.kubernetes\.io/enforce}' restricted 0
cka_sim::grade::assert_field_eq namespace "$CKA_SIM_LAB_NS" \
  '{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}' v1.35 0

# Assertion 3 — admission log carries v1.25+ PSS violation wording (setup-created).
if grep -qE '(would violate|violates) PodSecurity "(privileged|baseline|restricted):(v1\.[0-9]+|latest)":' "$log_file" 2>/dev/null; then
  ok "admission log uses v1.25+ PodSecurity wording (precondition; no points)"
else
  err "admission log missing expected PodSecurity wording (precondition)"
fi

# Assertion 4 — q04-compliant Deployment exists (setup-created).
cka_sim::grade::assert_resource_exists deployment q04-compliant -n "$CKA_SIM_LAB_NS" 0

# Assertion 5 — q04-compliant has at least one ready replica (setup-waited).
ready=$(kubectl get deployment q04-compliant -n "$CKA_SIM_LAB_NS" \
          -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
if [[ "${ready:-0}" =~ ^[1-9][0-9]*$ ]]; then
  ok "q04-compliant has ready replicas (precondition; no points)"
else
  err "q04-compliant has no ready replicas (precondition)"
fi

# ---------- Scoring assertion (candidate work) ----------

# Phase 07.1 D-16 — score the candidate's actual deliverable.
# Q04 is pedagogy-thin (audit-escape per CONTEXT D-22): without this assertion,
# all 5 preconditions are setup-state. Candidate's task per question.md ends
# with kubectl apply -f /tmp/q04-pss-enforce/candidate-violator.yaml, producing
# Pod q04-candidate.
cka_sim::grade::assert_resource_candidate_authored pod q04-candidate -n "$CKA_SIM_LAB_NS"

# ---------- Trap detection ----------

# Route through lib/traps.sh detectors. Single source of truth for the two
# declared traps; no inline greps. Detectors operate on raw candidate YAML
# text (no kubectl call) so they cost nothing.
cand_content=""
[[ -r "$candidate_file" ]] && cand_content=$(cat "$candidate_file")

hit=$(cka_sim::trap::detect_pss_error_string_mismatch "$cand_content")
[[ -n "$hit" ]] && cka_sim::grade::record_trap "$hit"

hit=$(cka_sim::trap::detect_psp_fictional_pod_label_exemption "$cand_content")
[[ -n "$hit" ]] && cka_sim::grade::record_trap "$hit"

cka_sim::grade::emit_result
