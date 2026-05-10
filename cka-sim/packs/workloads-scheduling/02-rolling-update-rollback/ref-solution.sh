#!/bin/bash
# workloads-scheduling/02-rolling-update-rollback/ref-solution.sh — set image -> verify -> undo.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# 1. Roll forward to nginx:1.27.
kubectl set image deployment/web app=nginx:1.27 -n "$CKA_SIM_LAB_NS"

# 2. Verify the rollout completed (required by the question's step 2).
kubectl rollout status deployment/web -n "$CKA_SIM_LAB_NS" --timeout=120s

# 3. Roll back one revision so the image returns to nginx:1.25.
kubectl rollout undo deployment/web -n "$CKA_SIM_LAB_NS"

# 4. Verify the rollback completed so grade.sh's final image check passes.
kubectl rollout status deployment/web -n "$CKA_SIM_LAB_NS" --timeout=120s
