#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" services-networking services-coredns-resolution
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" services-networking services-coredns-resolution 120

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q03-dnsclient
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q03-dnsclient
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
      - 1.1.1.1
  containers:
    - name: dnsclient
      image: busybox:1.37
      command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/q03-dnsclient -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
