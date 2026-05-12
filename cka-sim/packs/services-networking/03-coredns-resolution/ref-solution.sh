#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

dns_ip=$(kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
[[ -n "$dns_ip" ]] || { echo "ERROR: kube-dns ClusterIP not found" >&2; exit 1; }

kubectl delete pod q03-dnsclient -n "$CKA_SIM_LAB_NS" --wait=true --ignore-not-found
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
      - ${dns_ip}
  containers:
    - name: dnsclient
      image: busybox:1.37
      command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/q03-dnsclient -n "$CKA_SIM_LAB_NS" --timeout=60s
