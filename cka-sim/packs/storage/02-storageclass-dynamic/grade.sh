#!/bin/bash
# storage/02-storageclass-dynamic/grade.sh
# Phase 07.1 D-23 — assert_resource_exists/assert_pvc_bound can leak when SC fast-ssd
# persists from previous runs (reset.sh only deletes if cka-sim/uses label present).
# Fix: demote setup-presence checks to weight=0; sole scoring is assert_resource_candidate_authored.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Give the binder up to 60s to settle once the candidate creates the SC.
# Behavioural (GRADE-02): kubectl wait against a jsonpath is the canonical form.
kubectl wait --for=jsonpath='{.status.phase}'=Bound \
  pvc/app-cache -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true

# Precondition (weight=0): StorageClass fast-ssd must exist — informational only.
# Could pre-exist from stale reset; only gated assertion below scores.
cka_sim::grade::assert_resource_exists storageclass fast-ssd 0

# Precondition (weight=0): PVC app-cache must be Bound — informational only.
# Binds automatically if SC exists from previous run.
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" app-cache 0

# Scoring assertion: Candidate must have created StorageClass fast-ssd (not pre-existing).
cka_sim::grade::assert_resource_candidate_authored storageclass fast-ssd

# Trap detector: if PVC is still Pending AND SC fast-ssd does not exist,
# record pvc-wrong-storageclass (the seeded content-bug trap).
phase=$(kubectl get pvc app-cache -n "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
sc_exists=$(kubectl get storageclass fast-ssd -o name 2>/dev/null || echo "")
if [[ "$phase" == "Pending" && -z "$sc_exists" ]]; then
  cka_sim::grade::record_trap pvc-wrong-storageclass
fi

# Finalize — prints SCORE + Trap N: lines to stdout.
cka_sim::grade::emit_result
