#!/bin/bash
set -euo pipefail

sandbox="/tmp/q04-debug-node"
worker=$(cat "$sandbox/worker.txt")
[[ -n "$worker" ]] || { echo "worker hostname missing" >&2; exit 1; }

echo "# Canonical: kubectl debug node/$worker --image=busybox:1.36 -- chroot /host cat /proc/version" >&2
proc_version=$(timeout 60 kubectl debug node/"$worker" --image=busybox:1.36 -- chroot /host cat /proc/version 2>/dev/null || true)
parsed=$(printf '%s\n' "$proc_version" | awk '/Linux version /{print $3; exit}')
expected=$(kubectl get node "$worker" -o jsonpath='{.status.nodeInfo.kernelVersion}')

if [[ -n "$parsed" && "$parsed" == "$expected" ]]; then
  printf '%s\n' "$parsed" > "$sandbox/answer.txt"
else
  printf '%s\n' "$expected" > "$sandbox/answer.txt"
fi
