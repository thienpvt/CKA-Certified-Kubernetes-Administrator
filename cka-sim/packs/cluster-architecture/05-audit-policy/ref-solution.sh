#!/bin/bash
set -euo pipefail

mkdir -p /tmp/q05-audit-policy
cat > /tmp/q05-audit-policy/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]
  - level: Request
    resources:
      - group: ""
        resources: ["configmaps"]
  - level: None
    resources:
      - group: ""
        resources: ["events"]
EOF
