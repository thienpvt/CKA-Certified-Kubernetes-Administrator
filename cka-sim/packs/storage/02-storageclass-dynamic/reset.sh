#!/bin/bash
# storage/02-storageclass-dynamic/reset.sh — async ns delete + cluster-scoped SC cleanup.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 0. Wipe baseline capture dir (Phase 07.1 — lint-packs Pass I compliance).
rm -rf /tmp/cka-sim/02-storageclass-dynamic/

# 1. Async ns delete (runner owns cleanup; TRIP-03 pattern).
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped — unconditionally delete fast-ssd SC.
# Phase 07.1 D-26 — original label-gated deletion caused stale SCs to persist
# across runs (when an earlier candidate created fast-ssd without the label),
# leaking 1pt on subsequent empty submissions via the candidate-authored check.
# Single-user exam runner has no "concurrent labs" concern.
kubectl delete storageclass fast-ssd --ignore-not-found

# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/storage-storageclass-dynamic/"

exit 0
