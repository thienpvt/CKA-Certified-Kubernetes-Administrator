#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

ns="$CKA_SIM_LAB_NS"

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
        forward . /etc/resolv.conf
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
              subPath: Corefile
      volumes:
        - name: config
          configMap:
            name: q03-coredns-corefile
            items:
              - key: Corefile
                path: Corefile
EOF

kubectl rollout restart deployment/q03-coredns -n "$ns"
kubectl rollout status deployment/q03-coredns -n "$ns" --timeout=60s 2>/dev/null || true
