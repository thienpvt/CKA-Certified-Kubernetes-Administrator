#!/bin/bash
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

# Assertion 1: Deployment has a toleration for key=gpu with effect=NoSchedule.
cka_sim::grade::assert_field_eq deployment q08-gpu-sim \
  '{.spec.template.spec.tolerations[?(@.key=="gpu")].effect}' \
  'NoSchedule' -n "$CKA_SIM_LAB_NS"

# Assertion 2: required nodeAffinity with matchExpression key=gpu, operator=In.
cka_sim::grade::assert_field_eq deployment q08-gpu-sim \
  '{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[?(@.key=="gpu")].operator}' \
  'In' -n "$CKA_SIM_LAB_NS"

# Assertion 3: every replica lands on node-02 (no other node names).
# jsonpath emits a space-separated stream of nodeName values.
nodes=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=q08-gpu-sim -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null || echo "")
unique_nodes=$(echo "$nodes" | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$nodes" ]] && [[ "$unique_nodes" == "node-02" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("all replicas land on node-02")
  ok "all replicas land on node-02"
else
  CKA_SIM_GRADE_FAILS+=("replicas are on nodes '${nodes:-<none>}' (expected only node-02)")
  err "replicas are on nodes '${nodes:-<none>}' (expected only node-02)"
fi

# Assertion 4: node-02 has label gpu=true.
label=$(kubectl get node node-02 -o jsonpath='{.metadata.labels.gpu}' 2>/dev/null || echo "")
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$label" == "true" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("node-02 has label gpu=true")
  ok "node-02 has label gpu=true"
else
  CKA_SIM_GRADE_FAILS+=("node-02 label gpu='${label:-<unset>}' (expected 'true')")
  err "node-02 label gpu='${label:-<unset>}' (expected 'true')"
fi

cka_sim::grade::emit_result
