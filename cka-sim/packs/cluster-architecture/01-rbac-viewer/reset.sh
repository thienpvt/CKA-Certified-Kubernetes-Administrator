#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
# No cluster-scoped resources for this question (Role/RoleBinding/SA are all namespace-scoped)
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/cluster-architecture-rbac-viewer/"

exit 0
