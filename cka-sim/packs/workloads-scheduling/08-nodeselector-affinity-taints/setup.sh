#!/bin/bash
# workloads-scheduling/08-nodeselector-affinity-taints/setup.sh
# Seeds BROKEN Deployment q08-gpu-sim (no toleration, no nodeAffinity) and
# adds the gpu=true:NoSchedule taint to node-02. Candidate labels node-02
# with gpu=true + patches Deployment with toleration + required nodeAffinity.
#
# External dep: reset.sh MUST remove the gpu label + taint (cluster-scoped cleanup).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-nodeselector-affinity-taints
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-nodeselector-affinity-taints 120

# Add gpu=true:NoSchedule taint to node-02 (overwrite so re-runs are idempotent).
kubectl taint nodes node-02 gpu=true:NoSchedule --overwrite

# Intentionally DO NOT label node-02 -- that is the candidate's job.

# Broken Deployment: no tolerations, no nodeAffinity -> replicas stay Pending
# because they cannot tolerate node-02's taint and have no affinity pinning them
# to node-02. Requests included so the scheduler has real placement feedback.
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q08-gpu-sim
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q08-gpu-sim
spec:
  replicas: 2
  selector:
    matchLabels:
      app: q08-gpu-sim
  template:
    metadata:
      labels:
        app: q08-gpu-sim
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh","-c","sleep 3600"]
          resources:
            requests:
              cpu: 25m
              memory: 32Mi
EOF
