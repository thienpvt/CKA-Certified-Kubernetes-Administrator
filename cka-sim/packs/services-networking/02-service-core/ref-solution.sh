#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl patch service q02-web -n "$CKA_SIM_LAB_NS" --type=strategic -p '{"spec":{"selector":{"app":"q02-web"}}}'
sleep 5
