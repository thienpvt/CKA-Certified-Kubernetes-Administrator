#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" services-networking services-service-core
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" services-networking services-service-core 120

cka_sim::setup::seed_deployment "$CKA_SIM_LAB_NS" q02-web nginx:1.27 --replicas 3 --cpu 50m --memory 32Mi
kubectl label deployment q02-web -n "$CKA_SIM_LAB_NS" tier=backend --overwrite
kubectl patch deployment q02-web -n "$CKA_SIM_LAB_NS" --type=strategic -p '{"spec":{"template":{"metadata":{"labels":{"tier":"backend"}}}}}'

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: q02-web
  namespace: ${CKA_SIM_LAB_NS}
spec:
  type: ClusterIP
  selector:
    app: q02-web-typo
  ports:
    - port: 80
      targetPort: 80
EOF

kubectl wait --for=condition=Available deployment/q02-web -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
