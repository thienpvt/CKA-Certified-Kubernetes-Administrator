#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
# Phase 07.1 AUDIT-01: tear down per-question sandbox
rm -rf /tmp/cka-sim/01-networkpolicy-egress/
# No cluster-scoped resources for this question
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/services-networkpolicy-egress/"

exit 0
