#!/bin/bash
# workloads-scheduling/08-nodeselector-affinity-taints/setup.sh
# Seeds BROKEN Deployment q08-gpu-sim (no toleration, no nodeAffinity) and
# adds the gpu=true:NoSchedule taint to the first non-control-plane worker
# node (discovered dynamically so this works on clusters where the K8s node
# names differ from the Phase 1 BOOT-03 SSH aliases).
# Candidate labels the same worker with gpu=true + patches Deployment with
# toleration + required nodeAffinity.
#
# External dep: reset.sh MUST remove the gpu label + taint from the same
# worker (discovery idiom is identical across setup/reset/ref/grade).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-nodeselector-affinity-taints
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-nodeselector-affinity-taints 120

# Discover the target worker. Selector `!node-role.kubernetes.io/control-plane`
# excludes control-plane nodes; jsonpath picks the first worker deterministically.
target_node=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  --no-headers -o jsonpath='{.items[0].metadata.name}')
[[ -n "${target_node}" ]] || { echo "ERROR: no non-control-plane worker node found (q08 requires >=1 worker)" >&2; exit 1; }

# Add gpu=true:NoSchedule taint to the discovered worker (overwrite so re-runs are idempotent).
kubectl taint nodes "${target_node}" gpu=true:NoSchedule --overwrite

# Intentionally DO NOT label the worker with gpu=true -- that is the candidate's job.

# Broken Deployment: no tolerations, no nodeAffinity -> replicas stay Pending
# because they cannot tolerate the worker's taint and have no affinity pinning
# them to the target worker. Requests included so the scheduler has real
# placement feedback.
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
