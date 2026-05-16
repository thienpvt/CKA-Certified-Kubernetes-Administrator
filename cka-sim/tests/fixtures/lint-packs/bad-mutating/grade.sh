#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?}"
kubectl delete pod foo -n "$CKA_SIM_LAB_NS"
