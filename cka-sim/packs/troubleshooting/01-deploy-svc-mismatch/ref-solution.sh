#!/bin/bash
# troubleshooting/01-deploy-svc-mismatch/ref-solution.sh
# Reference fix: patches the Service selector to match the Deployment's pod labels.
# Invoked by GRADE-06 round-trip: bash setup.sh && bash ref-solution.sh && bash grade.sh
#   → expect SCORE = max and zero traps.
# Candidates NEVER see this file during drills.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

kubectl patch service web-svc -n "$CKA_SIM_LAB_NS" \
  --type='merge' \
  -p '{"spec":{"selector":{"app":"web"}}}'
