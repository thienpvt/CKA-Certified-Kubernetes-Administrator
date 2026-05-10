#!/bin/bash
# workloads-scheduling/03-configmap-secret-env-volume/setup.sh — seeds CM + Secret; candidate creates the Pod.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# 1. Idempotent lab namespace + Active wait.
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-configmap-secret-env-volume
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-configmap-secret-env-volume 120

# 2. Seed the ConfigMap + Secret the candidate must consume.
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: q03-app-config
  namespace: ${CKA_SIM_LAB_NS}
data:
  APP_MODE: production
---
apiVersion: v1
kind: Secret
metadata:
  name: q03-app-secret
  namespace: ${CKA_SIM_LAB_NS}
type: Opaque
stringData:
  API_KEY: q03-api-key-value
EOF
