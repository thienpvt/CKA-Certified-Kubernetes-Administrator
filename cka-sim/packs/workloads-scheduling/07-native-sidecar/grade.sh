#!/bin/bash
# Phase 07.1 AUDIT-01 — assert_resource_exists leak (setup creates Deployment) → assert_changed_since_setup
# workloads-scheduling/07-native-sidecar/grade.sh
# GRADE-02 compliance note: uses `wc -w` on space-separated jsonpath output
# to count containers -- the banned pipe-to-grep pattern is rejected by
# lint-packs.sh pass A.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Wait up to 60s for Available before reading spec (new rollout from candidate patch).
kubectl wait --for=condition=Available deployment/q07-app -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true

# Assertion 1: Deployment has been modified since setup (candidate patched it).
# Replaces assert_resource_exists which leaked 1 point on empty submission since setup creates the broken Deployment.
cka_sim::grade::assert_changed_since_setup deployment q07-app -n "$CKA_SIM_LAB_NS"

# Assertion 2: initContainer log-tailer exists and restartPolicy=Always (native sidecar shape).
cka_sim::grade::assert_field_eq deployment q07-app \
  '{.spec.template.spec.initContainers[?(@.name=="log-tailer")].restartPolicy}' \
  'Always' -n "$CKA_SIM_LAB_NS"

# Assertion 3: spec.containers has exactly 1 entry (the app container).
# GRADE-02: jsonpath emits a space-separated name stream — count with wc -w.
container_count=$(kubectl get deployment q07-app -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null | wc -w | tr -d ' ')
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$container_count" == "1" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("spec.containers has exactly 1 entry (sidecar moved to initContainers)")
  ok "spec.containers has exactly 1 entry (sidecar moved to initContainers)"
else
  CKA_SIM_GRADE_FAILS+=("spec.containers has $container_count entries (expected 1)")
  err "spec.containers has $container_count entries (expected 1)"
fi

# Trap detector: if the sidecar is still in spec.containers as a peer, record the primary trap.
has_peer_sidecar=$(kubectl get deployment q07-app -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="log-tailer")].name}' 2>/dev/null || echo "")
if [[ -n "$has_peer_sidecar" ]]; then
  cka_sim::grade::record_trap sidecar-not-native-restartpolicy-always
fi

cka_sim::grade::emit_result
