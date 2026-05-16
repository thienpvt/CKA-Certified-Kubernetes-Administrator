#!/bin/bash
# Phase 07.1 D-23 — services-networking/02-service-core/grade.sh
# Original leak: assert_field_eq on selector.app passes for free (setup writes the selector).
# Fix: demote selector/endpoints checks to weight=0; sole scoring assertion is
# assert_changed_since_setup (candidate must patch the Service).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Scoring assertion: Service modified since setup (candidate patched selector)
cka_sim::grade::assert_changed_since_setup service q02-web -n "$CKA_SIM_LAB_NS"

# Precondition (weight=0): selector matches deployment label — informational only.
# Setup writes this selector verbatim → leaks 1pt without weight=0.
cka_sim::grade::assert_field_eq service q02-web '{.spec.selector.app}' 'q02-web' -n "$CKA_SIM_LAB_NS" 0

# Precondition (weight=0): endpoints non-empty — informational + trap detection.
addr=$(kubectl get endpoints q02-web -n "$CKA_SIM_LAB_NS" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
if [[ -n "$addr" ]]; then
  ok "endpoints for service 'q02-web' are non-empty"
else
  err "endpoints for service 'q02-web' are empty"
  cka_sim::grade::record_trap service-selector-empty-endpoints
fi

cka_sim::grade::emit_result
