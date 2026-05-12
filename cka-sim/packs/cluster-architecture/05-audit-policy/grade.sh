#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

policy="/tmp/q05-audit-policy/policy.yaml"

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -s "$policy" ]]; then CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 )); ok "policy.yaml exists"; else CKA_SIM_GRADE_FAILS+=("policy.yaml missing"); err "policy.yaml missing"; fi

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

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if python3 - "$policy" <<'PY'
import sys, yaml
p = yaml.safe_load(open(sys.argv[1]))
assert len(p["rules"]) >= 1
PY
then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "policy has at least one rule"
else
  CKA_SIM_GRADE_FAILS+=("policy has no rules")
  err "policy has no rules"
fi

cka_sim::grade::emit_result
