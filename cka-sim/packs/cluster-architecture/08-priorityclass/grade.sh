#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

# Assertion 1: both q08 PriorityClasses still exist (no cheating by deletion).
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl get priorityclass q08-critical q08-batch -o name >/dev/null 2>&1; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "both q08 PriorityClasses exist"
else
  CKA_SIM_GRADE_FAILS+=("both q08 PriorityClasses must exist")
  err "both q08 PriorityClasses must exist"
  cka_sim::grade::record_trap priorityclass-globaldefault-conflict
fi

# Assertion 2: exactly one PriorityClass in the cluster is globalDefault.
# Uses storage/03's canonical jsonpath + wc -w idiom (space-stream, not
# newline-stream). Piping `kubectl get` to `grep` is banned by lint-packs
# pass A (GRADE-02); space-stream + `wc -w` is the accepted replacement.
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
