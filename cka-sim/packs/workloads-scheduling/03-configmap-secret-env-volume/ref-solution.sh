#!/bin/bash
# workloads-scheduling/03-configmap-secret-env-volume/ref-solution.sh — dedicated SA + Pod with env + Secret volume.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q03-app-sa
  namespace: ${CKA_SIM_LAB_NS}
---
apiVersion: v1
kind: Pod
metadata:
  name: q03-app
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q03-app
spec:
  serviceAccountName: q03-app-sa
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh","-c","sleep 3600"]
      env:
        - name: APP_MODE
          valueFrom:
            configMapKeyRef:
              name: q03-app-config
              key: APP_MODE
      volumeMounts:
        - name: app-secret
          mountPath: /etc/app-secrets
          readOnly: true
  volumes:
    - name: app-secret
      secret:
        secretName: q03-app-secret
        items:
          - key: API_KEY
            path: api-key
EOF

# Wait for the Pod to be Ready before exiting (round-trip: setup -> ref-solution -> grade).
kubectl wait --for=condition=Ready pod/q03-app -n "$CKA_SIM_LAB_NS" --timeout=60s
