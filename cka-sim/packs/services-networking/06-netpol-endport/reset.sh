#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
rm -rf /tmp/cka-sim/06-netpol-endport/
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
# 3. Remove per-question baseline dir
rm -rf "/tmp/cka-sim/services-netpol-endport/"

exit 0
