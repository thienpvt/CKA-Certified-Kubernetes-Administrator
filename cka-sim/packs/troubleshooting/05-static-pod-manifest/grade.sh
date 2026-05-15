#!/bin/bash
# troubleshooting/05-static-pod-manifest/grade.sh
# Phase 07.1 AUDIT-01 — audit-escape.
# Phase 07.1 D-22 audit-escape: file-edit baseline gap (node-side static-pod manifest).
#   Candidate work is pure file-edit to /tmp/q05-staticpod/manifest.yaml.
#   Baseline schema captures only kubectl resources; no file-tracking. Setup writes a manifest with intentional
#   tab-indent + image-tag traps that must be fixed before the manifest parses + dry-run validates.
#   All current assertions (file exists, YAML-parseable, kind=Pod, client-dry-run passes) correctly require
#   candidate work since setup intentionally breaks them.
#   Captured in 07.1-12-AUDIT-ESCAPE.md for Plan 13 VERIFICATION consumption.
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

manifest="/tmp/q05-staticpod/manifest.yaml"

# Phase 07.1 AUDIT-01: setup-collision — setup writes manifest.yaml on disk; existence is setup-state, not candidate-driven.
#   Demoted to weight=0 (informational only; reported via passes/fails arrays but does NOT add to score).
if [[ -s "$manifest" ]]; then
  CKA_SIM_GRADE_PASSES+=("manifest.yaml exists (setup-owned)")
  ok "manifest.yaml exists (setup-owned)"
else
  CKA_SIM_GRADE_FAILS+=("manifest.yaml missing (setup-owned)")
  err "manifest.yaml missing (setup-owned)"
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if python3 - "$manifest" 2>/dev/null <<'PY'
import sys, yaml
yaml.safe_load(open(sys.argv[1]))
PY
then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("manifest parses as YAML")
  ok "manifest parses as YAML"
else
  CKA_SIM_GRADE_FAILS+=("manifest does not parse as YAML")
  err "manifest does not parse as YAML"
  cka_sim::grade::record_trap static-pod-manifest-bad-yaml
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if python3 - "$manifest" 2>/dev/null <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d.get("kind") == "Pod"
PY
then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("manifest kind is Pod")
  ok "manifest kind is Pod"
else
  CKA_SIM_GRADE_FAILS+=("manifest kind is not Pod")
  err "manifest kind is not Pod"
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if kubectl apply --dry-run=client -f "$manifest" >/dev/null 2>&1; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("manifest passes client dry-run")
  ok "manifest passes client dry-run"
else
  CKA_SIM_GRADE_FAILS+=("manifest fails client dry-run")
  err "manifest fails client dry-run"
fi

if img=$(python3 - "$manifest" 2>/dev/null <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
print(d["spec"]["containers"][0]["image"])
PY
)
then
  if [[ "$img" == *"doesnotexistXYZ"* ]]; then
    cka_sim::grade::record_trap static-pod-image-tag-typo
  fi
else
  err "manifest image could not be extracted (YAML parse or schema failure)"
  cka_sim::grade::record_trap static-pod-manifest-bad-yaml
fi

cka_sim::grade::emit_result
