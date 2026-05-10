#!/bin/bash
# storage/02-storageclass-dynamic/grade.sh — asserts StorageClass fast-ssd exists
# + PVC app-cache Bound; records pvc-wrong-storageclass trap if the seed condition
# (Pending + no SC) still holds.
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

# Assertion 1: StorageClass fast-ssd must exist (cluster-scoped).
cka_sim::grade::assert_resource_exists storageclass fast-ssd

# Assertion 2: PVC app-cache must be Bound.
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" app-cache

# Assertion 3: PVC still references fast-ssd (candidate did not smuggle in another SC).
cka_sim::grade::assert_field_eq pvc app-cache \
  '{.spec.storageClassName}' \
  'fast-ssd' \
  -n "$CKA_SIM_LAB_NS"

# Trap detector: if PVC is still Pending AND SC fast-ssd does not exist,
# record pvc-wrong-storageclass (the seeded content-bug trap).
phase=$(kubectl get pvc app-cache -n "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
sc_exists=$(kubectl get storageclass fast-ssd -o name 2>/dev/null || echo "")
if [[ "$phase" == "Pending" && -z "$sc_exists" ]]; then
  cka_sim::grade::record_trap pvc-wrong-storageclass
fi

# Finalize — prints SCORE + Trap N: lines to stdout.
cka_sim::grade::emit_result
