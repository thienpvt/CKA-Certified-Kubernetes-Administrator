#!/bin/bash
# workloads-scheduling/01-deployment-requests/reset.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Async ns delete (cleans up Deployment, SA, all namespaced resources)
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Phase 07.1 AUDIT-01: clean per-question tmp scratch (baseline + transient artefacts).
rm -rf /tmp/cka-sim/01-deployment-requests/

# No cluster-scoped resources for this question
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/workloads-deployment-requests/"

exit 0
