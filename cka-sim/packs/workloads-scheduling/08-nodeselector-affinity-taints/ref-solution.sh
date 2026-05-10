#!/bin/bash
# workloads-scheduling/08-nodeselector-affinity-taints/ref-solution.sh
# Labels node-02 with gpu=true and patches q08-gpu-sim with a toleration
# for the NoSchedule taint + required nodeAffinity pinning replicas to
# nodes with label gpu=true.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl label nodes node-02 gpu=true --overwrite

kubectl patch deployment q08-gpu-sim -n "$CKA_SIM_LAB_NS" --type=strategic -p='{
  "spec": {
    "template": {
      "spec": {
        "tolerations": [
          {"key":"gpu","operator":"Equal","value":"true","effect":"NoSchedule"}
        ],
        "affinity": {
          "nodeAffinity": {
            "requiredDuringSchedulingIgnoredDuringExecution": {
              "nodeSelectorTerms": [
                {"matchExpressions": [{"key":"gpu","operator":"In","values":["true"]}]}
              ]
            }
          }
        }
      }
    }
  }
}'

kubectl rollout status deployment/q08-gpu-sim -n "$CKA_SIM_LAB_NS" --timeout=120s
