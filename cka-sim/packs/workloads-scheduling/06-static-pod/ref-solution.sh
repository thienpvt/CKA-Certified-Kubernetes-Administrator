#!/bin/bash
# workloads-scheduling/06-static-pod/ref-solution.sh
# Drops a static-pod manifest into /etc/kubernetes/manifests on node-01 via SSH
# and waits for the kubelet to mirror it into the default namespace.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

ssh -o BatchMode=yes node-01 'sudo tee /etc/kubernetes/manifests/q06-static-nginx.yaml >/dev/null' <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: q06-static-nginx
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
EOF

# kubelet polls /etc/kubernetes/manifests every ~20s; give it up to 60s to mirror the pod.
for _ in $(seq 1 12); do
  if kubectl get pod q06-static-nginx-node-01 -n default -o name >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

kubectl wait --for=condition=Ready pod/q06-static-nginx-node-01 -n default --timeout=120s
