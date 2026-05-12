#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete crd q06widgets.cka-sim.io --ignore-not-found
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
