#!/bin/bash
# storage/05-wait-for-first-consumer/ref-solution.sh — creates a dedicated ServiceAccount and
# Pod q05-consumer that mounts q05-claim. Scheduling the Pod triggers the WFFC binder to
# resolve q05-claim -> q05-wffc-pv. Answers all three assertions and avoids the default-SA trap.
# Invoked by GRADE-06 round-trip: bash setup.sh && bash ref-solution.sh && bash grade.sh -> SCORE = 3/3 + 0 traps.
# NOT exposed to candidates during drills.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Dedicated ServiceAccount (avoids default-sa-used trap) + Pod that mounts the PVC.
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q05-consumer-sa
  namespace: ${CKA_SIM_LAB_NS}
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: q05-consumer
  namespace: ${CKA_SIM_LAB_NS}
spec:
  serviceAccountName: q05-consumer-sa
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: q05-claim
EOF

# Wait for the WFFC binder to transition the PVC to Bound (triggered by pod scheduling).
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/q05-claim -n "$CKA_SIM_LAB_NS" --timeout=60s
kubectl wait --for=condition=Ready pod/q05-consumer -n "$CKA_SIM_LAB_NS" --timeout=60s
