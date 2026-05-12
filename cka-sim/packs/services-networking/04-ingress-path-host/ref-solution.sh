#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: q04-web
  namespace: ${CKA_SIM_LAB_NS}
spec:
  ingressClassName: q04-nginx
  rules:
    - host: api.example.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: q04-web
                port:
                  number: 80
EOF
