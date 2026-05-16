#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: q06-allow-range
  namespace: ${CKA_SIM_LAB_NS}
spec:
  podSelector:
    matchLabels:
      app: q06-server
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: q06-client
      ports:
        - protocol: TCP
          port: 8080
          endPort: 8090
EOF

sleep 5
