#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" services-networking services-ingress-path-host
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" services-networking services-ingress-path-host 120

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: q04-nginx
  labels:
    cka-sim/pack: services-networking
    cka-sim/question-id: services-ingress-path-host
spec:
  controller: k8s.io/ingress-placeholder
EOF

cka_sim::setup::seed_deployment "$CKA_SIM_LAB_NS" q04-web nginx:1.27 --replicas 2
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: q04-web
  namespace: ${CKA_SIM_LAB_NS}
spec:
  type: ClusterIP
  selector:
    app: q04-web
  ports:
    - port: 80
      targetPort: 80
EOF

kubectl wait --for=condition=Available deployment/q04-web -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
