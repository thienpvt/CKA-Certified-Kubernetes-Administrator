#!/bin/bash
# Phase 07.1 AUDIT-1 — no leak (mirror pod kubelet-created from candidate file) → header + candidate-authored assertion
# Phase 07.1 D-22 audit-escape: on-worker static-pod check; kubectl-stub fixture model partially applies (mirror pod is namespaced)
# workloads-scheduling/06-static-pod/grade.sh
# cka-sim-lint: allow-node-literal  # legacy fixture/ref path keeps node-01 fallback for static-pod audit coverage
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Give the kubelet time to mirror the static pod (poll interval ~20s by default).
# Support the current worker-1 naming plus the legacy node-01 fixture/ref path.
mirror_pod="q06-static-nginx-worker-1"
if ! kubectl get pod "$mirror_pod" -n default -o name >/dev/null 2>&1; then
  mirror_pod="q06-static-nginx-node-01"
fi
kubectl wait --for=condition=Ready "pod/$mirror_pod" -n default --timeout=60s 2>/dev/null || true

# Assertion 1: mirror pod is candidate-authored (kubelet creates it from candidate's manifest drop).
cka_sim::grade::assert_resource_candidate_authored pod "$mirror_pod" -n default

# Assertion 2: annotation kubernetes.io/config.source == file (proves it is kubelet-mirrored).
cka_sim::grade::assert_field_eq pod "$mirror_pod" \
  '{.metadata.annotations.kubernetes\.io/config\.source}' 'file' -n default

# Assertion 3: pod Ready.
cka_sim::grade::assert_pod_ready default "$mirror_pod"

# Trap detector (Phase 12 LINT-1): if pod exists but kubernetes.io/config.source
# annotation != "file", the candidate created it via kubectl apply rather than
# dropping the manifest into the kubelet's /etc/kubernetes/manifests/ dir.
if kubectl get pod "$mirror_pod" -n default >/dev/null 2>&1; then
  cfg_source=$(kubectl get pod "$mirror_pod" -n default \
    -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}' 2>/dev/null || echo "")
  if [[ -n "$cfg_source" && "$cfg_source" != "file" ]]; then
    cka_sim::grade::record_trap static-pod-applied-via-kubectl-apply
  fi
fi

cka_sim::grade::emit_result
