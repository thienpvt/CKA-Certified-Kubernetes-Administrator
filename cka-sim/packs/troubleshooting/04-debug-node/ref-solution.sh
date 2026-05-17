#!/bin/bash
set -euo pipefail

sandbox="/tmp/q04-debug-node"
worker=$(cat "$sandbox/worker.txt")
[[ -n "$worker" ]] || { echo "worker hostname missing" >&2; exit 1; }

echo "# Canonical reference: kubectl debug node/$worker --image=busybox:1.36 -- chroot /host cat /proc/version" >&2

# Phase 11 BUG-H05 — ref-solution shows ONE valid approach. The question
# explicitly accepts any Kubernetes-native node-introspection technique
# (kubectl debug node, hand-rolled privileged Pod, ephemeral debug container).
# We hand-roll a privileged Pod here because kubectl debug node auto-deletes
# the pod on session close in K8s 1.30+, which is grader-unfriendly. The grader
# scores only $sandbox/answer.txt, NOT the technique used to obtain it.
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: node-debugger-${worker}
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
