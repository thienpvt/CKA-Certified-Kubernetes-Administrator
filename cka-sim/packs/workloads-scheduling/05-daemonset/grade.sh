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

# Assertion 2: DaemonSet rolled out to every node it SHOULD cover.
# Phase 07.1 D-27 — original comparison `desiredNumberScheduled == kubectl get nodes`
# was wrong on clusters with non-schedulable nodes (cordoned, NotReady, additional
# taints not tolerated by the DS). desiredNumberScheduled is already what kube-controller
# computed as "nodes this DS targets given its tolerations". Compare numberReady to it.
desired=$(kubectl get daemonset q05-node-agent -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
ready=$(kubectl get daemonset q05-node-agent -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$desired" ]] && [[ -n "$ready" ]] && (( desired > 0 )) && (( ready == desired )); then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("DaemonSet fully rolled out: $ready/$desired nodes ready")
  ok "DaemonSet fully rolled out: $ready/$desired nodes ready"
else
  CKA_SIM_GRADE_FAILS+=("DaemonSet not fully rolled out: numberReady=$ready desired=$desired")
  err "DaemonSet not fully rolled out: numberReady=$ready desired=$desired"
fi

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
