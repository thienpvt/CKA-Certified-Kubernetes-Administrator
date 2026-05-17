#!/bin/bash
# cluster-architecture/05-audit-policy/grade.sh
# Phase 13 BUG-M05 — replace the single bundled "structure valid" weight=1
# assertion with 4 weight=1 scoring assertions (one per question requirement):
#   A: some rule has level=Metadata AND covers 'secrets'
#   B: some rule has level=Request  AND covers 'configmaps'
#   C: some rule has level=None     AND covers 'events'
#   D: omitStages contains 'RequestReceived'
# Weight=0 informational checks (file exists, has >=1 rule) preserved.
# audit-policy-wrong-stage-verbosity trap fires if any of the 4 scoring
# assertions fail — signals stage/verbosity mapping is wrong.
# Setup-state ownership: setup.sh writes a stub rule WITHOUT level → all 4
# scoring assertions fail until candidate edits. Ref-solution scores 4/4.
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

policy="/tmp/q05-audit-policy/policy.yaml"

# Setup-state assertion (weight=0): policy.yaml is written by setup.sh.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 0 ))
if [[ -s "$policy" ]]; then ok "policy.yaml exists [weight=0 setup-state]"; else err "policy.yaml missing [weight=0 setup-state]"; fi

# Track whether any of the 4 scoring assertions fails — fires the
# audit-policy-wrong-stage-verbosity trap once if so.
audit_any_fail=0

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if python3 - "$policy" <<'PY'
import sys, yaml
p = yaml.safe_load(open(sys.argv[1])) or {}
rules = p.get("rules") or []
def covers(rule, want):
    for r in rule.get("resources", []) or []:
        if want in (r.get("resources") or []):
            return True
    return False
assert any(rule.get("level") == "Metadata" and covers(rule, "secrets") for rule in rules), \
    "no rule maps secrets at level=Metadata"
PY
then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("Secrets logged at level=Metadata")
  ok "Secrets logged at level=Metadata"
else
  CKA_SIM_GRADE_FAILS+=("Secrets must be logged at level=Metadata")
  err "Secrets must be logged at level=Metadata"
  audit_any_fail=1
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if python3 - "$policy" <<'PY'
import sys, yaml
p = yaml.safe_load(open(sys.argv[1])) or {}
rules = p.get("rules") or []
def covers(rule, want):
    for r in rule.get("resources", []) or []:
        if want in (r.get("resources") or []):
            return True
    return False
assert any(rule.get("level") == "Request" and covers(rule, "configmaps") for rule in rules), \
    "no rule maps configmaps at level=Request"
PY
then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("ConfigMaps logged at level=Request")
  ok "ConfigMaps logged at level=Request"
else
  CKA_SIM_GRADE_FAILS+=("ConfigMaps must be logged at level=Request")
  err "ConfigMaps must be logged at level=Request"
  audit_any_fail=1
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if python3 - "$policy" <<'PY'
import sys, yaml
p = yaml.safe_load(open(sys.argv[1])) or {}
rules = p.get("rules") or []
def covers(rule, want):
    for r in rule.get("resources", []) or []:
        if want in (r.get("resources") or []):
            return True
    return False
assert any(rule.get("level") == "None" and covers(rule, "events") for rule in rules), \
    "no rule maps events at level=None"
PY
then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("Events logged at level=None")
  ok "Events logged at level=None"
else
  CKA_SIM_GRADE_FAILS+=("Events must be logged at level=None")
  err "Events must be logged at level=None"
  audit_any_fail=1
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if python3 - "$policy" <<'PY'
import sys, yaml
p = yaml.safe_load(open(sys.argv[1])) or {}
omit = p.get("omitStages") or []
assert "RequestReceived" in omit, "omitStages must contain RequestReceived"
PY
then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("omitStages contains RequestReceived")
  ok "omitStages contains RequestReceived"
else
  CKA_SIM_GRADE_FAILS+=("omitStages must contain RequestReceived")
  err "omitStages must contain RequestReceived"
  audit_any_fail=1
fi

if (( audit_any_fail == 1 )); then
  cka_sim::grade::record_trap audit-policy-wrong-stage-verbosity
fi

# Setup-state assertion (weight=0): setup.sh already writes one rule entry.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 0 ))
if python3 - "$policy" <<'PY'
import sys, yaml
p = yaml.safe_load(open(sys.argv[1])) or {}
rules = p.get("rules") or []
assert len(rules) >= 1
PY
then
  ok "policy has at least one rule [weight=0 setup-state]"
else
  err "policy has no rules [weight=0 setup-state]"
fi

cka_sim::grade::emit_result
