#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q04-pss-enforce"
mkdir -p "$sandbox"

# Ref-solution owns ONLY the candidate submission file. Setup owns the
# admission log, the reference violator Pod, the compliant Deployment,
# and the namespace PSS labels — ref-solution must NOT touch any of them.
#
# Compliant Pod shape: runs nginx-unprivileged (non-root image), declares
# runAsNonRoot at pod level, seccompProfile=RuntimeDefault, and at container
# level drops ALL capabilities with allowPrivilegeEscalation=false.
# Contains neither trigger string (no legacy PSS wording reference, no
# fictional pod-label exemption key) so both detectors in grade.sh
# return empty and no traps fire.
cat > "$sandbox/candidate-violator.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q04-candidate
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q04-candidate
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: nginxinc/nginx-unprivileged:1.27-alpine
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
EOF

# Phase 07.1 D-26 — actually create the candidate pod. The previous ref-solution
# only wrote the manifest to disk; grader requires q04-candidate to exist.
kubectl apply -f "$sandbox/candidate-violator.yaml"

# Wait for the candidate pod to be Ready (or at least admitted).
kubectl wait --for=condition=Ready pod/q04-candidate -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true
