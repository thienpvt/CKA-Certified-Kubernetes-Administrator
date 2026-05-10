#!/bin/bash
# storage/02-storageclass-dynamic/ref-solution.sh — creates StorageClass fast-ssd
# backed by rancher.io/local-path (already present on lab cluster per exercise 12)
# + dummy consumer pod to trigger WaitForFirstConsumer binding.
# Invoked by GRADE-06 round-trip: setup.sh && ref-solution.sh && grade.sh -> 3/3, 0 traps.
# NOT exposed to candidates during drills.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# 1. StorageClass fast-ssd — WaitForFirstConsumer matches the upstream local-path default.
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF

# 2. WaitForFirstConsumer needs a scheduled consumer before the binder will provision.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-cache-consumer
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-storageclass-dynamic
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "60"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-cache
EOF

# 3. Wait for the PVC to reach Bound — confirms the provisioner is serving the SC.
kubectl wait --for=jsonpath='{.status.phase}'=Bound \
  pvc/app-cache -n "$CKA_SIM_LAB_NS" --timeout=90s
