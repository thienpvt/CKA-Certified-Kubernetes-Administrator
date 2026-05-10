#!/bin/bash
# workloads-scheduling/08-nodeselector-affinity-taints/reset.sh
# Cluster-scoped cleanup: removes both the gpu=true label AND the
# gpu=true:NoSchedule taint from node-02 so later questions do not see
# unexpected scheduler behaviour on this node.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Untaint node-02 (trailing dash on key = remove).
kubectl taint nodes node-02 gpu- --overwrite 2>/dev/null || true

# Unlabel node-02 (trailing dash on key = remove).
kubectl label nodes node-02 gpu- --overwrite 2>/dev/null || true

exit 0
