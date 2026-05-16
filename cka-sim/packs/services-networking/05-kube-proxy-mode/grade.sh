#!/bin/bash
# Phase 07.1 AUDIT-01 — services-networking/05-kube-proxy-mode/grade.sh
# Risk: MEDIUM — sandbox file is seeded with WRONG mode 'ipvs'; without a
# candidate-write check, "iptables ≠ ipvs" mismatch correctly fails on empty,
# but the valid-enum assertion would pass (1/3) since 'ipvs' is a valid token.
# Fix: detect candidate-overwrite via setup-seeded-mode sentinel; if the file
# still equals the seeded value, treat as "no candidate work" and skip downstream.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# --- Assertion 0: candidate overwrote the sandbox file (not still seeded) ---
seeded=$(cat /tmp/q05-kube-proxy/.setup-seeded-mode 2>/dev/null | tr -d '[:space:]')
reported=$(cat /tmp/q05-kube-proxy/reported-mode.txt 2>/dev/null | tr -d '[:space:]')

candidate_wrote=0
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$reported" && -n "$seeded" && "$reported" != "$seeded" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("candidate overwrote /tmp/q05-kube-proxy/reported-mode.txt")
  ok "candidate overwrote /tmp/q05-kube-proxy/reported-mode.txt"
  candidate_wrote=1
else
  CKA_SIM_GRADE_FAILS+=("/tmp/q05-kube-proxy/reported-mode.txt unchanged from seeded value '${seeded:-<unknown>}'")
  err "/tmp/q05-kube-proxy/reported-mode.txt unchanged from seeded value '${seeded:-<unknown>}'"
fi

# --- Assertion 1: extract live kube-proxy mode (read-only) ---
live_mode=$(kubectl -n kube-system get configmap kube-proxy -o jsonpath='{.data.config\.conf}' 2>/dev/null \
  | awk '/^mode:/{print $2}' | tr -d '"')
# Empty mode means kubeadm default = iptables on Linux
[[ -z "$live_mode" ]] && live_mode=iptables

# --- Assertion 2: reported value matches live mode (gated on candidate write) ---
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if (( candidate_wrote == 1 )) && [[ "$reported" == "$live_mode" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("reported mode matches live cluster mode ($live_mode)")
  ok "reported mode matches live cluster mode ($live_mode)"
else
  CKA_SIM_GRADE_FAILS+=("reported mode '$reported' does not match live mode '$live_mode'")
  err "reported mode '$reported' does not match live mode '$live_mode'"
  cka_sim::grade::record_trap kube-proxy-mode-mismatch-ipvs-iptables
fi

# --- Assertion 3: reported value is a valid kube-proxy mode enum (gated on candidate write) ---
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if (( candidate_wrote == 1 )) && [[ "$reported" =~ ^(iptables|ipvs|nftables)$ ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("reported value '$reported' is a valid kube-proxy mode")
  ok "reported value '$reported' is a valid kube-proxy mode"
else
  CKA_SIM_GRADE_FAILS+=("reported value '$reported' is not a valid kube-proxy mode (expected iptables|ipvs|nftables)")
  err "reported value '$reported' is not a valid kube-proxy mode"
  cka_sim::grade::record_trap kube-proxy-mode-mismatch-ipvs-iptables
fi

cka_sim::grade::emit_result
