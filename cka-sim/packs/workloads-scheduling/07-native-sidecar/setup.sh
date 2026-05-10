#!/bin/bash
# workloads-scheduling/07-native-sidecar/setup.sh
# Seeds BROKEN Deployment q07-app with sidecar smuggled as spec.containers[1]
# (the trap). Candidate must move log-tailer into the init-container slot with
# restartPolicy=Always (v1.35 native sidecar shape).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-native-sidecar
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-native-sidecar 120

# Broken form: log-tailer declared as a peer container (spec.containers[1]).
# This runs, but it does NOT have native-sidecar semantics (no restartPolicy=Always,
# lifecycle-coupled exits, not part of init chain).
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q07-app
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q07-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q07-app
  template:
    metadata:
      labels:
        app: q07-app
    spec:
      containers:
        - name: app
          image: nginx:1.27
          volumeMounts:
            - name: shared
              mountPath: /shared
        - name: log-tailer
          image: busybox:1.36
          command: ["sh","-c","while true; do echo q07-log \$(date) >> /shared/app.log; sleep 1; done"]
          volumeMounts:
            - name: shared
              mountPath: /shared
      volumes:
        - name: shared
          emptyDir: {}
EOF
