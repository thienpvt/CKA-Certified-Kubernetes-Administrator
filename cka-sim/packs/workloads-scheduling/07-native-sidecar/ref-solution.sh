#!/bin/bash
# workloads-scheduling/07-native-sidecar/ref-solution.sh
# Replaces the Deployment spec with the native-sidecar shape:
# log-tailer moves from spec.containers[1] into spec.initContainers[] with
# restartPolicy: Always (v1.35 canonical native sidecar).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q07-app
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q07-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q07-app
  template:
    metadata:
      labels:
        app: q07-app
    spec:
      initContainers:
        - name: log-tailer
          image: busybox:1.36
          restartPolicy: Always
          command: ["sh","-c","while true; do echo q07-log \$(date) >> /shared/app.log; sleep 1; done"]
          volumeMounts:
            - name: shared
              mountPath: /shared
      containers:
        - name: app
          image: nginx:1.27
          volumeMounts:
            - name: shared
              mountPath: /shared
      volumes:
        - name: shared
          emptyDir: {}
EOF

kubectl rollout status deployment/q07-app -n "$CKA_SIM_LAB_NS" --timeout=120s
