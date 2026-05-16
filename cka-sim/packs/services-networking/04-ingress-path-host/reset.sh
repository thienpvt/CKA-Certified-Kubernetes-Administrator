#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
kubectl delete ingressclass q04-nginx --ignore-not-found
# Phase 07.1 AUDIT-01: tear down per-question sandbox
rm -rf /tmp/cka-sim/04-ingress-path-host/
exit 0
