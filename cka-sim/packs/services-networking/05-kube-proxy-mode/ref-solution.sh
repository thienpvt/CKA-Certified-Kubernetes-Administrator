#!/bin/bash
set -euo pipefail

# Extract the live kube-proxy mode from the ConfigMap (read-only)
live_mode=$(kubectl -n kube-system get configmap kube-proxy -o jsonpath='{.data.config\.conf}' 2>/dev/null \
  | awk '/^mode:/{print $2}' | tr -d '"')

# Empty mode means kubeadm default = iptables on Linux
[[ -z "$live_mode" ]] && live_mode=iptables

# Write the correct mode into the sandbox file
echo "$live_mode" > /tmp/q05-kube-proxy/reported-mode.txt
chmod 0644 /tmp/q05-kube-proxy/reported-mode.txt
