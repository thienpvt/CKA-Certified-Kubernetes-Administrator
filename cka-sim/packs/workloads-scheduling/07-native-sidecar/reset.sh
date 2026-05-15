#!/bin/bash
# workloads-scheduling/07-native-sidecar/reset.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/workloads-native-sidecar/"

exit 0
