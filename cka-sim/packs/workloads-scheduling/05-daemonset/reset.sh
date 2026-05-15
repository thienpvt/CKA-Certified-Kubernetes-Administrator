#!/bin/bash
# workloads-scheduling/05-daemonset/reset.sh — async ns delete (tears down DaemonSet + SA + pods).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# No cluster-scoped resources to clean — DaemonSet + SA are namespaced.
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/workloads-daemonset/"

exit 0
