#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" services-networking services-netpol-endport
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" services-networking services-netpol-endport 120

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q06-server
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q06-server
spec:
  containers:
    - name: server
      image: nicolaka/netshoot:v0.13
      command:
        - /bin/bash
        - -c
        - |
          for p in \$(seq 8080 8090); do
            while true; do printf 'HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nok\n' | nc -l -p "\$p"; done &
          done
          wait
      ports:
        - containerPort: 8080
        - containerPort: 8081
        - containerPort: 8082
        - containerPort: 8083
        - containerPort: 8084
        - containerPort: 8085
        - containerPort: 8086
        - containerPort: 8087
        - containerPort: 8088
        - containerPort: 8089
        - containerPort: 8090
---
apiVersion: v1
kind: Service
metadata:
  name: q06-server
  namespace: ${CKA_SIM_LAB_NS}
spec:
  selector:
    app: q06-server
  ports:
    - name: p8080
      port: 8080
      targetPort: 8080
    - name: p8085
      port: 8085
      targetPort: 8085
    - name: p8090
      port: 8090
      targetPort: 8090
    - name: p8095
      port: 8095
      targetPort: 8095
---
apiVersion: v1
kind: Pod
metadata:
  name: q06-client
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q06-client
spec:
  containers:
    - name: client
      image: nicolaka/netshoot:v0.13
      command: ["sleep", "3600"]
EOF

cka_sim::setup::seed_netpol_skeleton "$CKA_SIM_LAB_NS" q06-baseline app=q06-client

# Supplemental client-egress NetworkPolicy: UNIONs with the q06-baseline DNS
# egress so q06-client can resolve names AND reach q06-server on TCP 8080-8090.
# The DNS-only baseline from seed_netpol_skeleton stays untouched (shared helper
# signature is locked per 05-01-SUMMARY.md). Without this egress allowance the
# ref-solution's ingress policy alone cannot grade 6/6: baseline denies all
# non-DNS egress from q06-client so the 8085 probe (assertion 5) times out.
# Topping out at endPort 8090 keeps the 8095 out-of-range probe (assertion 6)
# failing from the client side even in the broken state.
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: q06-client-egress
  namespace: ${CKA_SIM_LAB_NS}
spec:
  podSelector:
    matchLabels:
      app: q06-client
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: q06-server
      ports:
        - protocol: TCP
          port: 8080
          endPort: 8090
EOF

kubectl wait --for=condition=Ready pod/q06-server -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=Ready pod/q06-client -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true

# Phase 13 BUG-M04 — CNI-enforcement probe.
# Apply a temp deny-all-ingress NP scoped to q06-server, then wget from q06-client.
# On enforcing CNI the probe times out → sentinel='true'. On non-enforcing CNI
# the wget succeeds despite the deny-all → sentinel='false'. The grader reads
# this sentinel to decide whether to run the reachability matrix or only score
# structural NP authoring. Idempotent: same NP name, sentinel overwritten, NP cleaned.
mkdir -p /tmp/q06-netpol-endport
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: q06-cni-probe-deny
  namespace: ${CKA_SIM_LAB_NS}
spec:
  podSelector:
    matchLabels:
      app: q06-server
  policyTypes:
    - Ingress
EOF
sleep 3  # allow CNI to program rules
if kubectl exec -n "$CKA_SIM_LAB_NS" q06-client -- wget -qO- --timeout=3 q06-server:8085 >/dev/null 2>&1; then
  printf 'false\n' > /tmp/q06-netpol-endport/.cni-enforces
else
  printf 'true\n'  > /tmp/q06-netpol-endport/.cni-enforces
fi
kubectl delete networkpolicy q06-cni-probe-deny -n "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false 2>/dev/null || true
