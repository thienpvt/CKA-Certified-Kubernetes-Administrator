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

# Phase 10 BUG-H03 — ref-solution writes the file only. The grader inspects
# /tmp/q04-pss-enforce/candidate-violator.yaml directly via kubectl apply
# --dry-run=client (no live apply). Restoring kubectl apply here would
# re-introduce the question/grader contradiction documented in BUG-H03.
