#!/bin/bash
# workloads-scheduling/04-hpa-metrics-server/ref-solution.sh — installs metrics-server v0.7.2
# (with --kubelet-insecure-tls for kubeadm self-signed kubelet certs) and creates HPA v2.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# 1. Install metrics-server idempotently.
# WR-01 (04-REVIEW.md): the manifest below is fetched live from github.com
# without SHA256 verification. A follow-up plan will vendor the pinned release
# under cka-sim/vendor/. Emit a loud warning and allow CKA_SIM_OFFLINE=1 as an
# opt-out that fails fast for air-gapped environments.
if [[ "${CKA_SIM_OFFLINE:-0}" == "1" ]]; then
  echo "ref-solution: CKA_SIM_OFFLINE=1 set and workloads/04 has no vendored metrics-server yet." >&2
  echo "              Unset CKA_SIM_OFFLINE to allow network fetch, or wait for the" >&2
  echo "              vendoring plan that addresses WR-01 in 04-REVIEW.md." >&2
  exit 1
fi
if ! kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  echo "WARN: workloads/04 fetching unsigned metrics-server v0.7.2 manifest from github.com (WR-01 pending full vendoring)" >&2
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml
  # kubeadm self-signed kubelet cert workaround.
  kubectl patch deployment metrics-server -n kube-system --type=json -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}
  ]'
fi
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=180s

# 2. Give metrics-server one scrape cycle before HPA queries land.
sleep 15

# 3. HPA v2 scaling 1 -> 5 at 50% CPU utilization.
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: q04-load
  namespace: ${CKA_SIM_LAB_NS}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: q04-load
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
EOF
