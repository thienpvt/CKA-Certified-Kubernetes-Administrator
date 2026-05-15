#!/bin/bash
# Phase 07.1 AUDIT-01 — no leak (DaemonSet candidate-authored; setup creates ns only) → header + candidate-authored assertion
# workloads-scheduling/05-daemonset/grade.sh — assert DaemonSet covers every Ready node, CP toleration present.
# Read-only: uses kubectl get + jsonpath only (no get|grep, no -A).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Wait up to 60s for the DaemonSet to settle before reading status (RESEARCH A4).
kubectl rollout status daemonset/q05-node-agent -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true

# Assertion 1: DaemonSet is candidate-authored (not pre-seeded by setup).
cka_sim::grade::assert_resource_candidate_authored daemonset q05-node-agent -n "$CKA_SIM_LAB_NS"

# Assertion 2: desiredNumberScheduled equals the cluster's node count (dynamic).
# `kubectl get nodes --no-headers` is read-only metadata, not a grep pattern.
node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
cka_sim::grade::assert_field_eq daemonset q05-node-agent \
  '{.status.desiredNumberScheduled}' "$node_count" -n "$CKA_SIM_LAB_NS"

# Assertion 3: toleration for node-role.kubernetes.io/control-plane with operator=Exists.
# The ref-solution adds two tolerations (NoSchedule + NoExecute) with the same key, so the
# jsonpath filter returns space-separated duplicates. Check that at least one "Exists" is present.
cp_op=$(kubectl get daemonset q05-node-agent -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="node-role.kubernetes.io/control-plane")].operator}' 2>/dev/null || echo "")
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$cp_op" == *"Exists"* ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("CP toleration operator contains 'Exists'")
  ok "CP toleration operator contains 'Exists'"
else
  CKA_SIM_GRADE_FAILS+=("CP toleration operator = '${cp_op:-<unset>}' (expected contains 'Exists')")
  err "CP toleration operator = '${cp_op:-<unset>}' (expected contains 'Exists')"
fi

# Assertion 4: container declares non-zero resources.requests.cpu (guards deployment-missing-requests trap).
cpu=$(kubectl get daemonset q05-node-agent -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$cpu" && "$cpu" != "0" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("container[0].resources.requests.cpu = '$cpu'")
  ok "container[0].resources.requests.cpu = '$cpu'"
else
  CKA_SIM_GRADE_FAILS+=("container[0].resources.requests.cpu empty or zero")
  err "container[0].resources.requests.cpu empty or zero"
fi

# Trap: default SA used by the daemon pods.
pod=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=q05-node-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$pod" ]]; then
  tid=$(cka_sim::trap::detect_default_sa_used "$CKA_SIM_LAB_NS" "$pod")
  [[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
fi

# Trap: DaemonSet missing control-plane toleration (primary trap for this scenario).
# Phase 07.1 AUDIT-01: gate on DS existence so empty submission doesn't fire a spurious trap.
ds_exists=$(kubectl get daemonset q05-node-agent -n "$CKA_SIM_LAB_NS" -o name 2>/dev/null || echo "")
if [[ -n "$ds_exists" ]]; then
  cp_toleration=$(kubectl get daemonset q05-node-agent -n "$CKA_SIM_LAB_NS" \
    -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="node-role.kubernetes.io/control-plane")].key}' 2>/dev/null || echo "")
  if [[ -z "$cp_toleration" ]]; then
    cka_sim::grade::record_trap daemonset-missing-control-plane-toleration
  fi
fi

cka_sim::grade::emit_result
