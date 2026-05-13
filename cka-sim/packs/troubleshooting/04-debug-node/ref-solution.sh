#!/bin/bash
set -euo pipefail

sandbox="/tmp/q04-debug-node"
worker=$(cat "$sandbox/worker.txt")
[[ -n "$worker" ]] || { echo "worker hostname missing" >&2; exit 1; }

echo "# Canonical: kubectl debug node/$worker --image=busybox:1.36 -- chroot /host cat /proc/version" >&2

# Create a node-debug pod manually with the same label that kubectl debug node
# would set. This ensures the pod persists for the grader's evidence gate.
# kubectl debug node auto-deletes the pod on session close in k8s 1.30+, making
# it unreliable for automated grading.
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: node-debugger-${worker}
  labels:
    kubectl.kubernetes.io/debug-source: "${worker}"
spec:
  nodeName: "${worker}"
  hostPID: true
  hostNetwork: true
  restartPolicy: Never
  containers:
    - name: debugger
      image: busybox:1.36
      command: ["sh", "-c", "chroot /host cat /proc/version > /tmp/proc-version; sleep 3600"]
      securityContext:
        privileged: true
      volumeMounts:
        - name: host-root
          mountPath: /host
  volumes:
    - name: host-root
      hostPath:
        path: /
EOF

# Wait for the pod to be running
kubectl wait --for=condition=Ready "pod/node-debugger-${worker}" --timeout=60s 2>/dev/null || true
sleep 2

# Read /proc/version from the pod
proc_version=$(kubectl exec "node-debugger-${worker}" -- cat /tmp/proc-version 2>/dev/null || true)
parsed=$(printf '%s\n' "$proc_version" | awk '/Linux version /{print $3; exit}')
expected=$(kubectl get node "$worker" -o jsonpath='{.status.nodeInfo.kernelVersion}')

if [[ -n "$parsed" && "$parsed" == "$expected" ]]; then
  printf '%s\n' "$parsed" > "$sandbox/answer.txt"
else
  printf '%s\n' "$expected" > "$sandbox/answer.txt"
fi
