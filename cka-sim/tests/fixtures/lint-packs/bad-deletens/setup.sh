#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?}"
kubectl delete ns "$CKA_SIM_LAB_NS" --ignore-not-found
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
EOF
