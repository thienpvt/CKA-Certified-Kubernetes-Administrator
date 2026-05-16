#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: q06widgets.cka-sim.io
  labels:
    cka-sim/pack: cluster-architecture
    cka-sim/question-id: cluster-architecture-crd-basics
spec:
  group: cka-sim.io
  scope: Namespaced
  names:
    plural: q06widgets
    singular: q06widget
    kind: Q06Widget
    shortNames:
      - q06w
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                size:
                  type: integer
EOF

kubectl wait --for=condition=Established crd/q06widgets.cka-sim.io --timeout=60s
kubectl apply -f - <<EOF
apiVersion: cka-sim.io/v1
kind: Q06Widget
metadata:
  name: q06-sample
  namespace: ${CKA_SIM_LAB_NS}
spec:
  size: 3
EOF
