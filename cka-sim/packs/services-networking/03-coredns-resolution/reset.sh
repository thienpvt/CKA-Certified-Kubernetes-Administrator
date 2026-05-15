#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/services-coredns-resolution/"

exit 0
