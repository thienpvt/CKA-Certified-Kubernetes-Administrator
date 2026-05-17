#!/bin/bash
# Phase 07.1 D-26 — cluster-architecture/08-priorityclass/grade.sh
# Phase 10 BUG-H04 — relaxed q08-critical hard-pin to accept either PC.
#
# Ownership analysis:
#   - setup.sh creates BOTH q08-critical and q08-batch PriorityClasses with
#     globalDefault=false. Existence is therefore setup-owned.
#   - Candidate work: flip exactly one of {q08-critical, q08-batch} to globalDefault=true.
#
# Honest scoring:
#   - Existence (setup-owned): weight=0 (informational only).
#   - exactly one globalDefault in cluster: weight=1 (proves they didn't flip both).
#   - default PC is one of {q08-critical, q08-batch}: weight=1 (matches question.md "exactly one of them" wording).
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

# Phase 10 BUG-H04 — drop q08-critical hard-pin (question.md says either
# q08-critical OR q08-batch may be flipped). Replaced with the "in allowed
# set" check below, which runs after the "exactly one globalDefault"
# assertion and reuses its $names variable.

# Candidate-work assertion 1: exactly one PriorityClass in the cluster is
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

# Phase 10 BUG-H04 — Candidate-work assertion 2 (was: q08-critical hard-pin):
# the single globalDefault PriorityClass must be one of {q08-critical, q08-batch}.
# Catches a candidate who flipped a third PC (forbidden by question.md line 11)
# and a candidate who didn't flip anything (count != 1 from the previous
# assertion already failed; this fail message reinforces the diagnosis).
# Reuses $names and $count from the previous assertion — no extra kubectl call.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
# Trim whitespace; if count != 1, $names may be empty or multi-token — both fail.
default_pc=$(printf '%s' "$names" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')
if [[ "$count" == "1" ]] && { [[ "$default_pc" == "q08-critical" ]] || [[ "$default_pc" == "q08-batch" ]]; }; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("default PriorityClass is one of {q08-critical, q08-batch} (got '$default_pc')")
  ok "default PriorityClass is one of {q08-critical, q08-batch} (got '$default_pc')"
else
  CKA_SIM_GRADE_FAILS+=("default PriorityClass is not one of {q08-critical, q08-batch} (got '$default_pc')")
  err "default PriorityClass is not one of {q08-critical, q08-batch} (got '$default_pc')"
  cka_sim::grade::record_trap priorityclass-globaldefault-conflict
fi

cka_sim::grade::emit_result
