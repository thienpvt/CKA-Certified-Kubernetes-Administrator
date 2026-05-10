#!/bin/bash
# workloads-scheduling/03-configmap-secret-env-volume/reset.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Async ns delete (cleans up Pod, SA, ConfigMap, Secret — all namespaced).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# No cluster-scoped resources for this question.
exit 0
