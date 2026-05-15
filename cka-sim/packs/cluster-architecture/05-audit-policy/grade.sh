#!/bin/bash
# Phase 07.1 AUDIT-01 — distinguish setup-state from candidate work.
# Phase 07.1 D-22 audit-escape: file-baseline gap.
#
# cluster-architecture/05-audit-policy/grade.sh
#
# Ownership analysis:
#   - setup.sh writes /tmp/q05-audit-policy/policy.yaml with apiVersion/kind/rules
#     scaffold but NO rules[].level (broken state).
#   - Candidate work: edit policy.yaml to add valid level/omitStages per audit
#     Policy v1 schema.
#   - "file exists" and "has at least one rule" both pass on setup-owned content.
#     Demoted to weight=0 (diagnostic only).
#   - "structure valid" (rules[].level in allowed set, omitStages valid) is the
#     only assertion that proves candidate work; scored at weight=1.
#   - File-baseline gap: lib/baseline.sh (D-03) tracks K8s API resources only;
#     v1.x scope expansion needed for file-mtime + sha256 baseline support.
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

policy="/tmp/q05-audit-policy/policy.yaml"

# Setup-state assertion (weight=0): policy.yaml is written by setup.sh.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 0 ))
if [[ -s "$policy" ]]; then ok "policy.yaml exists [weight=0 setup-state]"; else err "policy.yaml missing [weight=0 setup-state]"; fi

# Candidate-work assertion (weight=1): policy must parse + every rule has a
# valid level. Setup's stub has rules without level so this fails until candidate fixes.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if python3 - "$policy" <<'PY'
import sys, yaml
allowed_levels = {"None", "Metadata", "Request", "RequestResponse"}
allowed_stages = {"RequestReceived", "ResponseStarted", "ResponseComplete", "Panic"}
p = yaml.safe_load(open(sys.argv[1]))
assert p.get("apiVersion") == "audit.k8s.io/v1"
assert p.get("kind") == "Policy"
assert p.get("rules")
for rule in p["rules"]:
    assert rule.get("level") in allowed_levels
for stage in p.get("omitStages", []):
    assert stage in allowed_stages
PY
then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "audit policy structure valid"
else
  CKA_SIM_GRADE_FAILS+=("audit policy structure invalid")
  err "audit policy structure invalid"
  cka_sim::grade::record_trap audit-policy-wrong-stage-verbosity
fi

# Setup-state assertion (weight=0): setup.sh already writes one rule entry.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 0 ))
if python3 - "$policy" <<'PY'
import sys, yaml
p = yaml.safe_load(open(sys.argv[1]))
assert len(p["rules"]) >= 1
PY
then
  ok "policy has at least one rule [weight=0 setup-state]"
else
  err "policy has no rules [weight=0 setup-state]"
fi

cka_sim::grade::emit_result
