#!/bin/bash
# Phase 07.1 AUDIT-01 — services-networking/02-service-core/grade.sh
# Risk: MEDIUM — Service exists is setup-owned; selector/endpoints fail correctly on empty.
# Fix: gate Service existence on assert_changed_since_setup (candidate must patch selector).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertion 1: Service modified since setup (candidate patched selector)
cka_sim::grade::assert_changed_since_setup service q02-web -n "$CKA_SIM_LAB_NS"

# Assertion 2: selector matches deployment label
cka_sim::grade::assert_field_eq service q02-web '{.spec.selector.app}' 'q02-web' -n "$CKA_SIM_LAB_NS"

# Assertion 3: endpoints non-empty
addr=$(kubectl get endpoints q02-web -n "$CKA_SIM_LAB_NS" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$addr" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("endpoints for service 'q02-web' are non-empty")
  ok "endpoints for service 'q02-web' are non-empty"
else
  CKA_SIM_GRADE_FAILS+=("endpoints for service 'q02-web' are empty")
  err "endpoints for service 'q02-web' are empty"
  cka_sim::grade::record_trap service-selector-empty-endpoints
fi

cka_sim::grade::emit_result
