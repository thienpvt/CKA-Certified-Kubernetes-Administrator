#!/bin/bash
# workloads-scheduling/03-configmap-secret-env-volume/reset.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Async ns delete (cleans up Pod, SA, ConfigMap, Secret — all namespaced).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Phase 07.1 AUDIT-01: clean per-question tmp scratch (baseline + transient artefacts).
rm -rf /tmp/cka-sim/03-configmap-secret-env-volume/

# No cluster-scoped resources for this question.
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/workloads-configmap-secret-env-volume/"

exit 0
