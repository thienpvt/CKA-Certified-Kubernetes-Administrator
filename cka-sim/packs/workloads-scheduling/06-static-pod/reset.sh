#!/bin/bash
# workloads-scheduling/06-static-pod/reset.sh
# Deletes the lab namespace AND best-effort removes the static-pod manifest from node-01
# so the kubelet tears down the mirror pod. Safe to re-run.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Best-effort: remove static-pod manifest from node-01 (ignore errors if SSH fails or file absent).
ssh -o BatchMode=yes -o ConnectTimeout=5 node-01 'sudo rm -f /etc/kubernetes/manifests/q06-static-nginx.yaml' 2>/dev/null || true

exit 0
