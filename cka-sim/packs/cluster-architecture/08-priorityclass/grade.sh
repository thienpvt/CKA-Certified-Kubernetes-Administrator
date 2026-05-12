#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl get priorityclass q08-critical q08-batch -o name >/dev/null 2>&1; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "both q08 PriorityClasses exist"
else
  CKA_SIM_GRADE_FAILS+=("both q08 PriorityClasses must exist")
  err "both q08 PriorityClasses must exist"
  cka_sim::grade::record_trap priorityclass-globaldefault-conflict
fi

count=$(kubectl get priorityclass -o jsonpath='{range .items[?(@.globalDefault==true)]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -v '^$' | wc -l | tr -d ' ')
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
