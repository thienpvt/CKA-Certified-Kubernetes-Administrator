#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="cluster-architecture"
CKA_SIM_QUESTION_ID="cluster-architecture-priorityclass"
sandbox="/tmp/q08-priorityclass"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"

kubectl apply -f - <<'EOF'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: q08-critical
  labels:
    cka-sim/pack: cluster-architecture
    cka-sim/question-id: cluster-architecture-priorityclass
value: 2000000
globalDefault: true
description: "High-priority for critical workloads"
EOF

kubectl apply -f - <<'EOF' 2>&1 | tee "$sandbox/admission.log" >/dev/null || true
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: q08-batch
  labels:
    cka-sim/pack: cluster-architecture
    cka-sim/question-id: cluster-architecture-priorityclass
value: 100
globalDefault: true
description: "Batch workloads"
EOF

kubectl get priorityclass q08-batch >/dev/null 2>&1 || kubectl apply -f - <<'EOF'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: q08-batch
  labels:
    cka-sim/pack: cluster-architecture
    cka-sim/question-id: cluster-architecture-priorityclass
value: 100
globalDefault: false
description: "Batch workloads"
EOF
