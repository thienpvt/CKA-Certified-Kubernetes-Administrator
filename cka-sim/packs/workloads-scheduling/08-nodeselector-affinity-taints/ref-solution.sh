#!/bin/bash
# workloads-scheduling/08-nodeselector-affinity-taints/ref-solution.sh
# Labels the dynamically-discovered worker with gpu=true and patches
# q08-gpu-sim with a toleration for the NoSchedule taint + required
# nodeAffinity pinning replicas to nodes with label gpu=true.
#
# Discovery idiom is identical to setup.sh / reset.sh / grade.sh so this
# targets the same worker setup.sh tainted.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

target_node=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  --no-headers -o jsonpath='{.items[0].metadata.name}')
[[ -n "${target_node}" ]] || { echo "ERROR: no non-control-plane worker node found" >&2; exit 1; }

kubectl label nodes "${target_node}" gpu=true --overwrite

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
