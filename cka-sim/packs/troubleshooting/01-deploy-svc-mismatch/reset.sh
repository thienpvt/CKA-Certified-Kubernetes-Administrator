#!/bin/bash
# troubleshooting/01-deploy-svc-mismatch/reset.sh — async ns delete, best-effort.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Phase 07.1 AUDIT-01: per-question tmp cleanup (no candidate sandbox for this Q, but lint requires it).
rm -rf /tmp/cka-sim/01-deploy-svc-mismatch/

exit 0
