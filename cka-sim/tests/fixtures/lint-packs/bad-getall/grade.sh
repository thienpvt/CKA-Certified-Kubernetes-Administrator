#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?}"
kubectl get -A pods
