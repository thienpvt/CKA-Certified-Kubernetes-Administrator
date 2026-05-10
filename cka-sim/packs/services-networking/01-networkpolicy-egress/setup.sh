#!/bin/bash
# services-networking/01-networkpolicy-egress/setup.sh — NetworkPolicy with egress restrictions but no DNS allow.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# 1. ns + Active wait
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: services-networking
    cka-sim/question-id: services-networkpolicy-egress
EOF
phase=""
for i in $(seq 1 24); do
  phase=$(kubectl get ns "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [[ "$phase" == "Active" ]]; then
    break
  fi
  if [[ -z "$phase" ]]; then
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: services-networking
    cka-sim/question-id: services-networkpolicy-egress
EOF
  fi
  sleep 5
done
[[ "$phase" == "Active" ]] || { echo "ns not Active (phase=$phase)" >&2; exit 1; }

# 2. Probe pod (image MUST have bash + nslookup — netshoot is the canonical choice).
#    Per RESEARCH Assumption A3: busybox/alpine 'sh' lacks /dev/tcp and has inconsistent
#    nslookup behaviour. netshoot bundles bash + bind-tools + a stable nslookup.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: probe
spec:
  containers:
    - name: probe
      image: nicolaka/netshoot:v0.13
      command: ["sleep", "3600"]
EOF

# 3. NetworkPolicy: egress-restricted, allows traffic only to a fictional 10.0.0.0/8 CIDR.
#    INTENTIONAL TRAP: no rule permits UDP/53 to kube-dns -> nslookup fails.
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-restrict
  namespace: ${CKA_SIM_LAB_NS}
spec:
  podSelector:
    matchLabels:
      app: probe
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
      ports:
        - protocol: TCP
          port: 80
EOF

# 4. Wait for probe pod to be Ready
kubectl wait --for=condition=Ready pod/probe -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
