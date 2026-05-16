#!/bin/bash
# storage/06-pvc-mount-pod/ref-solution.sh — creates the correct Deployment:
# dedicated ServiceAccount, resource requests set, PVC mounted read-only at /data.
# Invoked by GRADE-06 round-trip: setup && ref-solution && grade -> SCORE max, 0 traps.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q06-reader-sa
  namespace: ${CKA_SIM_LAB_NS}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q06-reader
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q06-reader
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q06-reader
  template:
    metadata:
      labels:
        app: q06-reader
    spec:
      serviceAccountName: q06-reader-sa
      containers:
        - name: app
          image: nginx:1.27
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
          volumeMounts:
            - name: data
              mountPath: /data
              readOnly: true
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: q06-data
EOF

kubectl rollout status deployment/q06-reader -n "$CKA_SIM_LAB_NS" --timeout=120s
