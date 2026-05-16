#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="troubleshooting"
CKA_SIM_QUESTION_ID="troubleshooting-coredns-resolution"
ns="$CKA_SIM_LAB_NS"

cka_sim::setup::ensure_lab_ns "$ns" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$ns" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID" 120

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: q03-coredns-corefile
  namespace: ${ns}
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        # INTENTIONAL TRAP: forward upstream 203.0.113.53:53 is TEST-NET-3 (unroutable)
        forward . 203.0.113.53:53
        cache 30
        loop
        reload
        loadbalance
    }
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q03-coredns
  namespace: ${ns}
  labels:
    app.kubernetes.io/name: q03-coredns
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: q03-coredns
  template:
    metadata:
      labels:
        app.kubernetes.io/name: q03-coredns
    spec:
      containers:
        - name: coredns
          image: coredns/coredns:1.11.1
          args: ["-conf", "/etc/coredns/Corefile"]
          ports:
            - name: dns-udp
              containerPort: 53
              protocol: UDP
            - name: dns-tcp
              containerPort: 53
              protocol: TCP
          volumeMounts:
            - name: config
              mountPath: /etc/coredns/Corefile
              # INTENTIONAL TRAP: subPath 'corefile' does not match ConfigMap key 'Corefile' (case-sensitive)
              subPath: corefile
      volumes:
        - name: config
          configMap:
            name: q03-coredns-corefile
            items:
              - key: Corefile
                path: Corefile
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: q03-coredns
  namespace: ${ns}
spec:
  selector:
    app.kubernetes.io/name: q03-coredns
  ports:
    - name: dns-udp
      protocol: UDP
      port: 53
      targetPort: 53
    - name: dns-tcp
      protocol: TCP
      port: 53
      targetPort: 53
EOF

kubectl wait --for=condition=Available deployment/q03-coredns -n "$ns" --timeout=60s 2>/dev/null || true

clusterip=""
for _ in $(seq 1 30); do
  clusterip=$(kubectl get svc q03-coredns -n "$ns" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
  [[ -n "$clusterip" ]] && break
  sleep 1
done
[[ -n "$clusterip" ]] || die "q03-coredns Service ClusterIP not allocated after 30s"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q03-dnsclient
  namespace: ${ns}
  labels:
    app: q03-dnsclient
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
      - ${clusterip}
  containers:
    - name: dnsclient
      image: busybox:1.37
      command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/q03-dnsclient -n "$ns" --timeout=60s 2>/dev/null || true
