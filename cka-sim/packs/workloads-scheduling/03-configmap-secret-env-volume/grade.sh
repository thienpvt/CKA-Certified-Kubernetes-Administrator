#!/bin/bash
# Phase 07.1 AUDIT-01 — no leak (setup creates CM+Secret only; Pod is candidate-authored) → header added
# workloads-scheduling/03-configmap-secret-env-volume/grade.sh — read-only assertions.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Wait up to 60s for the candidate's Pod to be Ready before reading its spec.
kubectl wait --for=condition=Ready pod/q03-app -n "$CKA_SIM_LAB_NS" --timeout=60s 2>/dev/null || true

# Assertion 1: pod q03-app is Ready.
cka_sim::grade::assert_pod_ready "$CKA_SIM_LAB_NS" q03-app

# Assertion 2: APP_MODE env var wired via configMapKeyRef (not a literal value).
cka_sim::grade::assert_field_eq pod q03-app \
  '{.spec.containers[0].env[?(@.name=="APP_MODE")].valueFrom.configMapKeyRef.name}' \
  'q03-app-config' \
  -n "$CKA_SIM_LAB_NS"

cka_sim::grade::assert_field_eq pod q03-app \
  '{.spec.containers[0].env[?(@.name=="APP_MODE")].valueFrom.configMapKeyRef.key}' \
  'APP_MODE' \
  -n "$CKA_SIM_LAB_NS"

# Assertion 3: Secret volume mount at /etc/app-secrets is read-only.
cka_sim::grade::assert_field_eq pod q03-app \
  '{.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/app-secrets")].readOnly}' \
  'true' \
  -n "$CKA_SIM_LAB_NS"

# Behavioural probe A: env var visible in the running container.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
mode=$(kubectl exec -n "$CKA_SIM_LAB_NS" q03-app -- printenv APP_MODE 2>/dev/null | tr -d '\r\n ')
if [[ "$mode" == "production" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("env probe APP_MODE=production")
  ok "env probe APP_MODE=production"
else
  CKA_SIM_GRADE_FAILS+=("env probe APP_MODE='${mode}' (expected production)")
  err "env probe APP_MODE='${mode}' (expected production)"
fi

# Behavioural probe B: api-key file contents match seeded Secret value.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
key=$(kubectl exec -n "$CKA_SIM_LAB_NS" q03-app -- cat /etc/app-secrets/api-key 2>/dev/null | tr -d '\r\n ')
if [[ "$key" == "q03-api-key-value" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("secret file probe /etc/app-secrets/api-key matches seeded value")
  ok "secret file probe /etc/app-secrets/api-key matches seeded value"
else
  CKA_SIM_GRADE_FAILS+=("secret file probe /etc/app-secrets/api-key='${key}' (expected q03-api-key-value)")
  err "secret file probe /etc/app-secrets/api-key='${key}' (expected q03-api-key-value)"
fi

# Trap detector: probe the candidate's Pod for default SA usage.
tid=$(cka_sim::trap::detect_default_sa_used "$CKA_SIM_LAB_NS" q03-app)
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

cka_sim::grade::emit_result
