#!/bin/bash
# Phase 07.1 AUDIT-01 — field-eq checks correctly empty on setup-only; gate Deployment edits via assert_changed_since_setup
# workloads-scheduling/08-nodeselector-affinity-taints/grade.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Wait up to 90s for Available (scheduler needs time after candidate patch rolls out).
kubectl wait --for=condition=Available deployment/q08-gpu-sim -n "$CKA_SIM_LAB_NS" --timeout=90s 2>/dev/null || true

# Wait for rollout to complete and old-RS pods to terminate. rollout status returns
# when new RS is satisfied, but old pods may still be Running. Poll until pod count
# matches the desired replicas (2) so assertion 3 doesn't see stale pods.
# Phase 07.1 D-22 audit-escape: retries + sleep are env-overridable so kubectl-stub fixture
# tests don't pay the 30s wall-clock cost; defaults preserve production cluster behaviour.
kubectl rollout status deployment/q08-gpu-sim -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
desired=$(kubectl get deployment q08-gpu-sim -n "$CKA_SIM_LAB_NS" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "2")
poll_retries="${CKA_SIM_GRADE_POLL_RETRIES:-15}"
poll_sleep="${CKA_SIM_GRADE_POLL_SLEEP:-2}"
for _i in $(seq 1 "$poll_retries"); do
  count=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=q08-gpu-sim \
    --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
  (( count <= desired )) && break
  sleep "$poll_sleep"
done

# Discover target worker. Identical idiom to setup.sh / reset.sh / ref-solution.sh.
# On failure the discovery-dependent assertions auto-FAIL (soft fail -- do not exit).
target_node=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  --no-headers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

# Assertion 0: Deployment has been modified since setup (candidate patched it).
# Gates the remaining field checks — empty submission cannot pass on setup-state alone.
cka_sim::grade::assert_changed_since_setup deployment q08-gpu-sim -n "$CKA_SIM_LAB_NS"

# Assertion 1: Deployment has a toleration for key=gpu with effect=NoSchedule.
cka_sim::grade::assert_field_eq deployment q08-gpu-sim \
  '{.spec.template.spec.tolerations[?(@.key=="gpu")].effect}' \
  'NoSchedule' -n "$CKA_SIM_LAB_NS"

# Assertion 2: required nodeAffinity with matchExpression key=gpu, operator=In.
cka_sim::grade::assert_field_eq deployment q08-gpu-sim \
  '{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[?(@.key=="gpu")].operator}' \
  'In' -n "$CKA_SIM_LAB_NS"

# Assertion 3: every Running replica lands on the target worker.
nodes=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=q08-gpu-sim \
  --field-selector=status.phase=Running -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null || echo "")
unique_nodes=$(echo "$nodes" | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$nodes" ]] && [[ -n "$target_node" ]] && [[ "$unique_nodes" == "$target_node" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("all replicas land on ${target_node}")
  ok "all replicas land on ${target_node}"
else
  CKA_SIM_GRADE_FAILS+=("replicas are on nodes '${nodes:-<none>}' (expected only '${target_node:-<discovery-failed>}')")
  err "replicas are on nodes '${nodes:-<none>}' (expected only '${target_node:-<discovery-failed>}')"
fi

# Assertion 4: target worker has label gpu=true.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$target_node" ]]; then
  label=$(kubectl get node "$target_node" -o jsonpath='{.metadata.labels.gpu}' 2>/dev/null || echo "")
  if [[ "$label" == "true" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
    CKA_SIM_GRADE_PASSES+=("${target_node} has label gpu=true")
    ok "${target_node} has label gpu=true"
  else
    CKA_SIM_GRADE_FAILS+=("${target_node} label gpu='${label:-<unset>}' (expected 'true')")
    err "${target_node} label gpu='${label:-<unset>}' (expected 'true')"
  fi
else
  CKA_SIM_GRADE_FAILS+=("target worker discovery failed (no non-control-plane node visible)")
  err "target worker discovery failed (no non-control-plane node visible)"
fi

cka_sim::grade::emit_result
