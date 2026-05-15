#!/bin/bash
# Async lab ns delete for workloads-scheduling Q04.
# Per RESEARCH section 6.2 lines 570-573: do NOT uninstall the cluster-wide CPU
# scraper Deployment on reset. Other questions (and the candidate) rely on it
# remaining up. Only clean the lab namespace here.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Phase 07.1 AUDIT-01: clean per-question tmp scratch (baseline + transient artefacts).
rm -rf /tmp/cka-sim/04-hpa-metrics-server/

exit 0
