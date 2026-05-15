#!/bin/bash
# workloads-scheduling/06-static-pod/reset.sh
# Deletes the lab namespace AND best-effort removes the static-pod manifest from EVERY
# reachable node (not just node-01 — per 04-REVIEW.md WR-09: a candidate who drops the
# manifest on node-02 or the control plane would otherwise leave a mirror pod behind in
# the default namespace, invisible to the ns-scoped delete sweep).
# Safe to re-run; every rm is best-effort so SSH failures don't fail the reset.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Best-effort: sweep the static-pod manifest off every node kubectl knows about.
# Uses whatever SSH hostname the cluster node name resolves to (the Phase 1 cluster
# uses node-01/node-02 matching /etc/hosts). Ignore unreachable hosts silently.
while IFS= read -r node; do
  [[ -z "$node" ]] && continue
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$node" \
    'sudo rm -f /etc/kubernetes/manifests/q06-static-nginx.yaml' 2>/dev/null || true
done < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

# Phase 07.1 AUDIT-01: clean per-question tmp scratch (baseline + transient artefacts).
rm -rf /tmp/cka-sim/06-static-pod/

exit 0
