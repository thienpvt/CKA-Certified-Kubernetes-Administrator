#!/bin/bash
# workloads-scheduling/05-daemonset/ref-solution.sh — SA + DaemonSet with CP toleration + requests.
# Dual toleration covers both NoSchedule (vanilla kubeadm) and NoExecute (upgraded CP nodes) — RESEARCH §9 risk row.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q05-node-agent-sa
  namespace: ${CKA_SIM_LAB_NS}
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: q05-node-agent
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q05-node-agent
spec:
  selector:
    matchLabels:
      app: q05-node-agent
  template:
    metadata:
      labels:
        app: q05-node-agent
    spec:
      serviceAccountName: q05-node-agent-sa
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoExecute
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          resources:
            requests:
              cpu: 25m
              memory: 32Mi
EOF

kubectl rollout status daemonset/q05-node-agent -n "$CKA_SIM_LAB_NS" --timeout=120s
