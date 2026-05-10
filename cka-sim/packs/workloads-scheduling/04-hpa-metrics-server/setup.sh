#!/bin/bash
# workloads-scheduling/04-hpa-metrics-server/setup.sh — seeds a Deployment q04-load with
# CPU + memory requests + dedicated SA. Does NOT install metrics-server; that is the
# candidate's job (CG-06 / RESEARCH §2.2 Q04 + §6.2).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent ns create + 120s Active wait.
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-hpa-metrics-server
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-hpa-metrics-server 120

# 2. Dedicated SA for the load Deployment.
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q04-load-sa
  namespace: ${CKA_SIM_LAB_NS}
EOF

# 3. Deployment WITH CPU + memory requests (the trap here is metrics-server, not requests).
cka_sim::setup::seed_deployment "$CKA_SIM_LAB_NS" q04-load nginx:1.27 \
  --replicas 1 --sa q04-load-sa --cpu 100m --memory 64Mi

# 4. Best-effort wait for Available so the first candidate probe has a target.
kubectl wait --for=condition=Available deployment/q04-load -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
