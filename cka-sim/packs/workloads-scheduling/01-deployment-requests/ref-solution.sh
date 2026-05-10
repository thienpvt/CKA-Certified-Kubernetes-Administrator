#!/bin/bash
# workloads-scheduling/01-deployment-requests/ref-solution.sh — creates SA + patches Deployment.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# 1. Create the dedicated SA
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: load-app-sa
  namespace: ${CKA_SIM_LAB_NS}
EOF

# 2. Patch Deployment: set serviceAccountName + add resources.requests
kubectl patch deployment load-app -n "$CKA_SIM_LAB_NS" --type=strategic -p='{
  "spec": {
    "template": {
      "spec": {
        "serviceAccountName": "load-app-sa",
        "containers": [{
          "name": "app",
          "resources": {
            "requests": {
              "cpu": "50m",
              "memory": "64Mi"
            }
          }
        }]
      }
    }
  }
}'

# 3. Wait for new pods to roll out
kubectl rollout status deployment/load-app -n "$CKA_SIM_LAB_NS" --timeout=60s
