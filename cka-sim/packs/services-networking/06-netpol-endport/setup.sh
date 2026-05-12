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
          for p in $(seq 8080 8090); do
            while true; do printf 'HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nok\n' | nc -l -p "$p"; done &
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

kubectl wait --for=condition=Ready pod/q06-server -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=Ready pod/q06-client -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
