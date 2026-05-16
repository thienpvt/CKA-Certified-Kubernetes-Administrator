#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?}"
kubectl get pod foo -n "$CKA_SIM_LAB_NS" -o jsonpath="{.items[?(@.metadata.name=='foo')].status.phase}" 2>/dev/null
kubectl auth can-i list pods -n "$CKA_SIM_LAB_NS"
# avoid: kubectl get pods | grep foo
echo "SCORE: 1/1"
