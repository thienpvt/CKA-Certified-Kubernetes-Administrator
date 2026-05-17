#!/bin/bash
# Phase 07.1 D-16 / D-22: this question's grader is structurally thin —
# Phase 10 BUG-H03 — 5 preconditions are setup-state (weight=0); 5 scoring
# assertions check candidate-authored YAML at /tmp/q04-pss-enforce/candidate-violator.yaml directly per question.md.
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

# ---------- Scoring assertions (candidate-authored file) ----------
# Phase 10 BUG-H03 — score the candidate-violator.yaml file directly per
# question.md's literal claim ("the grader inspects file contents directly
# and does not require you to kubectl apply anything"). Each restricted-PSS
# field listed in question.md is one weight=1 assertion. kubectl apply
# --dry-run=client validates schema without touching the cluster.

# Pre-flight: candidate file must exist and be syntactically valid YAML.
if [[ ! -r "$candidate_file" ]]; then
  err "candidate-violator.yaml missing or unreadable at $candidate_file"
  CKA_SIM_GRADE_FAILS+=("candidate-violator.yaml missing or unreadable")
  # Do not exit — let the trap detectors and emit_result still run so the
  # candidate sees their score and traps in one shot.
fi

# Helper: query a single jsonpath against the candidate file via dry-run.
# Returns the extracted string (or empty) on stdout. --dry-run=client never
# contacts the apiserver, so this works even if the candidate's manifest
# would be rejected by the live PSS admission controller.
_q04_field() {
  local jp="$1"
  kubectl apply --dry-run=client -f "$candidate_file" -o jsonpath="$jp" 2>/dev/null
}

# Assertion 1 (weight=1): no privileged containers (privileged absent OR false).
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
privileged_vals=$(_q04_field '{.spec.containers[*].securityContext.privileged}')
# Pass: empty (field absent on every container) OR every token is "false".
pass_priv=1
if [[ -n "$privileged_vals" ]]; then
  for v in $privileged_vals; do
    [[ "$v" == "false" ]] || { pass_priv=0; break; }
  done
fi
if (( pass_priv == 1 )); then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("no privileged containers in candidate-violator.yaml")
  ok "no privileged containers in candidate-violator.yaml"
else
  CKA_SIM_GRADE_FAILS+=("candidate-violator.yaml has privileged container(s) (got '$privileged_vals')")
  err "candidate-violator.yaml has privileged container(s) (got '$privileged_vals')"
fi

# Assertion 2 (weight=1): pod-level runAsNonRoot == true.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
run_as_non_root=$(_q04_field '{.spec.securityContext.runAsNonRoot}')
if [[ "$run_as_non_root" == "true" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("pod-level runAsNonRoot: true")
  ok "pod-level runAsNonRoot: true"
else
  CKA_SIM_GRADE_FAILS+=("pod-level runAsNonRoot != true (got '${run_as_non_root:-<absent>}')")
  err "pod-level runAsNonRoot != true (got '${run_as_non_root:-<absent>}')"
fi

# Assertion 3 (weight=1): every container drops ALL capabilities.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
# Get container count + count of containers whose capabilities.drop list contains "ALL".
# We compare totals: pass iff every container has a drop list and every list contains "ALL".
container_count=$(_q04_field '{range .spec.containers[*]}{"x"}{end}')   # one "x" per container
drop_all_hits=$(_q04_field '{range .spec.containers[*]}{.securityContext.capabilities.drop}{"|"}{end}')
pass_drop=1
[[ -z "$container_count" ]] && pass_drop=0
if (( pass_drop == 1 )); then
  # Iterate per-container drop entries (separated by '|'), require each contains "ALL".
  IFS='|' read -ra _drops <<< "$drop_all_hits"
  n_containers=${#container_count}
  n_passes=0
  for d in "${_drops[@]}"; do
    [[ -z "$d" ]] && continue
    # The jsonpath array print yields tokens like "[ALL]" or "[NET_ADMIN ALL]".
    if [[ "$d" =~ (^|[^A-Z_])ALL([^A-Z_]|$) ]]; then
      n_passes=$(( n_passes + 1 ))
    fi
  done
  (( n_passes == n_containers )) || pass_drop=0
fi
if (( pass_drop == 1 )); then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("every container drops ALL capabilities")
  ok "every container drops ALL capabilities"
else
  CKA_SIM_GRADE_FAILS+=("not every container drops ALL capabilities (got '$drop_all_hits')")
  err "not every container drops ALL capabilities (got '$drop_all_hits')"
fi

# Assertion 4 (weight=1): seccompProfile.type == RuntimeDefault (pod-level).
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
seccomp_type=$(_q04_field '{.spec.securityContext.seccompProfile.type}')
if [[ "$seccomp_type" == "RuntimeDefault" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("pod-level seccompProfile.type: RuntimeDefault")
  ok "pod-level seccompProfile.type: RuntimeDefault"
else
  CKA_SIM_GRADE_FAILS+=("pod-level seccompProfile.type != RuntimeDefault (got '${seccomp_type:-<absent>}')")
  err "pod-level seccompProfile.type != RuntimeDefault (got '${seccomp_type:-<absent>}')"
fi

# Assertion 5 (weight=1): every container has allowPrivilegeEscalation: false.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
ape_vals=$(_q04_field '{.spec.containers[*].securityContext.allowPrivilegeEscalation}')
pass_ape=1
if [[ -z "$ape_vals" ]]; then
  pass_ape=0
else
  for v in $ape_vals; do
    [[ "$v" == "false" ]] || { pass_ape=0; break; }
  done
  # Also require one value per container (no missing fields).
  ape_count=$(printf '%s\n' $ape_vals | wc -w | tr -d ' ')
  [[ -n "$container_count" && "$ape_count" == "${#container_count}" ]] || pass_ape=0
fi
if (( pass_ape == 1 )); then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("every container has allowPrivilegeEscalation: false")
  ok "every container has allowPrivilegeEscalation: false"
else
  CKA_SIM_GRADE_FAILS+=("not every container has allowPrivilegeEscalation: false (got '$ape_vals')")
  err "not every container has allowPrivilegeEscalation: false (got '$ape_vals')"
fi

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
