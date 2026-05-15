#!/bin/bash
# Phase 07.1 AUDIT-01 — distinguish setup-state from candidate work.
#
# cluster-architecture/06-crd-basics/grade.sh
#
# Ownership analysis:
#   - setup.sh creates lab namespace + a readme ConfigMap (q06-readme). It does
#     NOT create the CRD or any Q06Widget — those are 100% candidate work.
#   - Candidate work: kubectl apply CRD q06widgets.cka-sim.io (scope=Namespaced,
#     group=cka-sim.io) + create at least one Q06Widget with numeric spec.size.
#   - Use assert_resource_candidate_authored on the CRD to prove the candidate
#     authored it (CRD must NOT be in baseline AND must currently exist).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

# Candidate-work assertion: CRD must be authored by candidate (not in baseline).
cka_sim::grade::assert_resource_candidate_authored crd q06widgets.cka-sim.io

scope=$(kubectl get crd q06widgets.cka-sim.io -o jsonpath='{.spec.scope}' 2>/dev/null || true)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$scope" == "Namespaced" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "CRD scope is Namespaced"
else
  CKA_SIM_GRADE_FAILS+=("CRD scope is '${scope:-<missing>}'")
  err "CRD scope is '${scope:-<missing>}'"
  cka_sim::grade::record_trap crd-missing-scope-field
fi

cka_sim::grade::assert_field_eq crd q06widgets.cka-sim.io '{.spec.group}' cka-sim.io

count=$(kubectl -n "$CKA_SIM_LAB_NS" get q06widgets.cka-sim.io -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l | tr -d ' ')
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "at least one Q06Widget exists"
else
  CKA_SIM_GRADE_FAILS+=("no Q06Widget resources found")
  err "no Q06Widget resources found"
fi

size=$(kubectl -n "$CKA_SIM_LAB_NS" get q06widgets.cka-sim.io -o jsonpath='{.items[0].spec.size}' 2>/dev/null || true)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$size" =~ ^[0-9]+$ ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "spec.size is numeric"
else
  CKA_SIM_GRADE_FAILS+=("spec.size is not numeric")
  err "spec.size is not numeric"
fi

cka_sim::grade::emit_result
