#!/bin/bash
# Phase 07.1 AUDIT-01 — distinguish setup-state from candidate work.
#
# cluster-architecture/08-priorityclass/grade.sh
#
# Ownership analysis:
#   - setup.sh creates BOTH q08-critical and q08-batch PriorityClasses with
#     globalDefault=false. Existence is therefore setup-owned.
#   - Candidate work: patch exactly one of them (q08-critical per ref-solution)
#     to globalDefault=true.
#   - Existence assertion passes from setup → weight=0.
#   - "exactly one globalDefault" assertion proves a flip happened → weight=1.
#   - assert_changed_since_setup on q08-critical proves THE candidate touched
#     the right resource (not some other PC), generation-bumped → weight=1.
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

# Setup-state assertion (weight=0): both q08 PriorityClasses exist (setup-owned).
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 0 ))
if kubectl get priorityclass q08-critical q08-batch -o name >/dev/null 2>&1; then
  ok "both q08 PriorityClasses exist [weight=0 setup-state]"
else
  err "both q08 PriorityClasses must exist [weight=0 setup-state]"
  cka_sim::grade::record_trap priorityclass-globaldefault-conflict
fi

# Candidate-work assertion 1: q08-critical must have been modified (flipped).
cka_sim::grade::assert_changed_since_setup priorityclass q08-critical 1

# Candidate-work assertion 2: exactly one PriorityClass in the cluster is
# globalDefault. Uses storage/03's canonical jsonpath + wc -w idiom.
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
