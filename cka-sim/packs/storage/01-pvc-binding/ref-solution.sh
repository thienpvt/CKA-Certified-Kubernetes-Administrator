#!/bin/bash
# storage/01-pvc-binding/ref-solution.sh — patches PV q01-app-pv to add nodeAffinity (the trap fix).
# Invoked by GRADE-06 round-trip: bash setup.sh && bash ref-solution.sh && bash grade.sh -> SCORE = max + 0 traps.
# NOT exposed to candidates during drills.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Patch the PV to add a permissive nodeAffinity (operator: Exists matches every node with the label key).
kubectl patch pv q01-app-pv --type=json -p='[
  {"op": "add", "path": "/spec/nodeAffinity", "value": {
    "required": {
      "nodeSelectorTerms": [{
        "matchExpressions": [{
          "key": "kubernetes.io/hostname",
          "operator": "Exists"
        }]
      }]
    }
  }}
]'
