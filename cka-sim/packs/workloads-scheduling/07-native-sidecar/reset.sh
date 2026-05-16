#!/bin/bash
# workloads-scheduling/07-native-sidecar/reset.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Phase 07.1 AUDIT-01: clean per-question tmp scratch (baseline + transient artefacts).
rm -rf /tmp/cka-sim/07-native-sidecar/

exit 0
