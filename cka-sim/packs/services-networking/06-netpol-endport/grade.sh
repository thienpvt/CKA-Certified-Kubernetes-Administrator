#!/bin/bash
# services-networking/06-netpol-endport/grade.sh
# Phase 13 BUG-M04 — CNI-enforcement-aware grader.
# Structural assertions (existence + port=8080 + endPort=8090 + protocol=TCP)
# are unconditional and act as the over-permissive guard. Reachability is
# branched on /tmp/q06-netpol-endport/.cni-enforces written by setup.sh:
#   true  → 4-port matrix (8080/8085/8090 reachable, 8095 NOT reachable),
#           each gated on candidate-authored NP via is_candidate_modified.
#   false → skip reachability; emit non-scoring info line.
#   missing → skip reachability; emit non-scoring err line (re-run setup).
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

kubectl wait --for=condition=Ready pod/q06-server -n "$CKA_SIM_LAB_NS" --timeout=30s 2>/dev/null || true
kubectl wait --for=condition=Ready pod/q06-client -n "$CKA_SIM_LAB_NS" --timeout=30s 2>/dev/null || true

# Structural authoring (over-permissive guard) — 4 weight=1 assertions.
cka_sim::grade::assert_resource_exists networkpolicy q06-allow-range -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_field_eq networkpolicy q06-allow-range '{.spec.ingress[0].ports[0].port}'    '8080' -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_field_eq networkpolicy q06-allow-range '{.spec.ingress[0].ports[0].endPort}' '8090' -n "$CKA_SIM_LAB_NS"

proto=$(kubectl get networkpolicy q06-allow-range -n "$CKA_SIM_LAB_NS" -o jsonpath='{.spec.ingress[0].ports[0].protocol}' 2>/dev/null || true)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$proto" == "TCP" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("NetworkPolicy q06-allow-range declares protocol TCP")
  ok "NetworkPolicy q06-allow-range declares protocol TCP"
else
  CKA_SIM_GRADE_FAILS+=("NetworkPolicy q06-allow-range missing protocol TCP")
  err "NetworkPolicy q06-allow-range missing protocol TCP"
  cka_sim::grade::record_trap netpol-endport-missing-protocol
fi

# np_authored=1 iff the NP exists in cluster AND is candidate-modified
# (or baseline missing — back-compat). Used to gate reachability so empty
# submission can't accidentally pass on default-allow networking.
np_authored=0
if cka_sim::baseline::is_candidate_modified networkpolicy q06-allow-range -n "$CKA_SIM_LAB_NS"; then
  if kubectl get networkpolicy q06-allow-range -n "$CKA_SIM_LAB_NS" -o name >/dev/null 2>&1; then
    np_authored=1
  fi
fi

sentinel="/tmp/q06-netpol-endport/.cni-enforces"
cni_enforces="missing"
if [[ -r "$sentinel" ]]; then
  cni_enforces=$(tr -d '[:space:]' < "$sentinel")
fi

if [[ "$cni_enforces" == "true" ]]; then
  # Reachable ports: 8080 (boundary), 8085 (in-range), 8090 (boundary).
  for port in 8080 8085 8090; do
    CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
    if (( np_authored == 1 )) \
       && kubectl exec -n "$CKA_SIM_LAB_NS" q06-client -- wget -qO- --timeout=3 q06-server:"$port" >/dev/null 2>&1; then
      CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
      CKA_SIM_GRADE_PASSES+=("q06-client reaches q06-server:$port (in allowed endPort range)")
      ok "q06-client reaches q06-server:$port (in allowed endPort range)"
    else
      if (( np_authored == 0 )); then
        CKA_SIM_GRADE_FAILS+=("reachability :$port skipped — no candidate-authored NetworkPolicy q06-allow-range")
        err "reachability :$port skipped — no candidate-authored NetworkPolicy"
      else
        CKA_SIM_GRADE_FAILS+=("q06-client cannot reach q06-server:$port (expected reachable in 8080-8090 range)")
        err "q06-client cannot reach q06-server:$port (expected reachable in 8080-8090 range)"
      fi
    fi
  done

  # Out-of-range port 8095 must NOT be reachable.
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
  if (( np_authored == 1 )) \
     && ! kubectl exec -n "$CKA_SIM_LAB_NS" q06-client -- wget -qO- --timeout=3 q06-server:8095 >/dev/null 2>&1; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
    CKA_SIM_GRADE_PASSES+=("q06-client cannot reach q06-server:8095 (out of allowed endPort range)")
    ok "q06-client cannot reach q06-server:8095 (out of allowed endPort range)"
  else
    if (( np_authored == 0 )); then
      CKA_SIM_GRADE_FAILS+=("unreachability :8095 skipped — no candidate-authored NetworkPolicy q06-allow-range")
      err "unreachability :8095 skipped — no candidate-authored NetworkPolicy"
    else
      CKA_SIM_GRADE_FAILS+=("q06-client can reach q06-server:8095 (NP appears over-permissive)")
      err "q06-client can reach q06-server:8095 (NP appears over-permissive)"
    fi
  fi
elif [[ "$cni_enforces" == "false" ]]; then
  ok "CNI non-enforcing — reachability not gradable; structural NP assertions only (no scoring impact)"
else
  err "CNI probe sentinel missing — reachability checks skipped, re-run setup (no scoring impact)"
fi

cka_sim::grade::emit_result
