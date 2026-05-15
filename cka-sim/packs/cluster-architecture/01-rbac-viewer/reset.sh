#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
# No cluster-scoped resources for this question (Role/RoleBinding/SA are all namespace-scoped)
# Phase 07.1 AUDIT-01 — purge canonical sandbox path
rm -rf /tmp/cka-sim/01-rbac-viewer/
exit 0
