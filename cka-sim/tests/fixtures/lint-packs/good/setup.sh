#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
EOF
# NOTE: do not 'kubectl delete ns' here — runner does that
