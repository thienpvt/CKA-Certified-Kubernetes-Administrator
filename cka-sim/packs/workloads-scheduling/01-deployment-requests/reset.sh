#!/bin/bash
# workloads-scheduling/01-deployment-requests/reset.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Async ns delete (cleans up Deployment, SA, all namespaced resources)
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# No cluster-scoped resources for this question
exit 0
