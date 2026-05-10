#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?}"
kubectl get pods -n "$CKA_SIM_LAB_NS" | grep app
