#!/bin/bash
# Phase 07.1 AUDIT-01 — no leak (mirror pod kubelet-created from candidate file) → header + candidate-authored assertion
# Phase 07.1 D-22 audit-escape: on-node static-pod check; kubectl-stub fixture model partially applies (mirror pod is namespaced)
# workloads-scheduling/06-static-pod/grade.sh
# cka-sim-lint: allow-node-literal  # drill is hostname-bound to the kubeadm CP node; dynamic discovery retrofit tracked in deferred-items
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Give the kubelet time to mirror the static pod (poll interval ~20s by default).
kubectl wait --for=condition=Ready pod/q06-static-nginx-node-01 -n default --timeout=60s 2>/dev/null || true

# Assertion 1: mirror pod is candidate-authored (kubelet creates it from candidate's manifest drop).
cka_sim::grade::assert_resource_candidate_authored pod q06-static-nginx-node-01 -n default

# Assertion 2: annotation kubernetes.io/config.source == file (proves it is kubelet-mirrored).
cka_sim::grade::assert_field_eq pod q06-static-nginx-node-01 \
  '{.metadata.annotations.kubernetes\.io/config\.source}' 'file' -n default

# Assertion 3: pod Ready.
cka_sim::grade::assert_pod_ready default q06-static-nginx-node-01

cka_sim::grade::emit_result
