#!/bin/bash
# Phase 07.1 D-26 — cluster-architecture/08-priorityclass/grade.sh
#
# Ownership analysis:
#   - setup.sh creates BOTH q08-critical and q08-batch PriorityClasses with
#     globalDefault=false. Existence is therefore setup-owned.
#   - Candidate work: patch q08-critical to globalDefault=true.
#
# Honest scoring:
#   - Existence (setup-owned): weight=0 (informational only).
#   - q08-critical.globalDefault==true: weight=1 (proves candidate did the work).
#   - exactly one globalDefault in cluster: weight=1 (proves they didn't flip both).
#
# NOTE: assert_changed_since_setup is unreliable here because the cluster-scoped
# baseline filter uses the question slug (08-priorityclass) which does not match
# the q##- prefixed PC names → back-compat triggers → leaks 1pt on empty.
# Replaced with deterministic field check.
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

# Setup-state assertion (weight=0): both q08 PriorityClasses exist (setup-owned).
if kubectl get priorityclass q08-critical q08-batch -o name >/dev/null 2>&1; then
  ok "both q08 PriorityClasses exist [weight=0 setup-state]"
else
  err "both q08 PriorityClasses must exist [weight=0 setup-state]"
  cka_sim::grade::record_trap priorityclass-globaldefault-conflict
fi

# Candidate-work assertion 1: q08-critical.globalDefault flipped to true.
# Setup creates with globalDefault=false; candidate must patch to true.
cka_sim::grade::assert_field_eq priorityclass q08-critical \
  '{.globalDefault}' 'true'

# Candidate-work assertion 2: exactly one PriorityClass in the cluster is
# globalDefault. Catches "flipped both" and "didn't flip anything" cases.
names=$(kubectl get priorityclass \
  -o jsonpath='{.items[?(@.globalDefault==true)].metadata.name}' 2>/dev/null || echo "")
count=$(printf '%s' "$names" | wc -w | tr -d ' ')
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$count" == "1" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "exactly one PriorityClass is globalDefault"
else
  CKA_SIM_GRADE_FAILS+=("expected exactly one globalDefault PriorityClass, got $count")
  err "expected exactly one globalDefault PriorityClass, got $count"
  cka_sim::grade::record_trap priorityclass-globaldefault-conflict
fi

cka_sim::grade::emit_result
