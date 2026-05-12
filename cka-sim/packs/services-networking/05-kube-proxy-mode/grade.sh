#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# --- Assertion 1: Extract the live kube-proxy mode (read-only) ---
live_mode=$(kubectl -n kube-system get configmap kube-proxy -o jsonpath='{.data.config\.conf}' 2>/dev/null \
  | awk '/^mode:/{print $2}' | tr -d '"')
# Empty mode means kubeadm default = iptables on Linux
[[ -z "$live_mode" ]] && live_mode=iptables

# --- Assertion 2: Read candidate's reported mode ---
reported=$(cat /tmp/q05-kube-proxy/reported-mode.txt 2>/dev/null | tr -d '[:space:]')

# Check reported value matches live mode
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$reported" == "$live_mode" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("reported mode matches live cluster mode ($live_mode)")
  ok "reported mode matches live cluster mode ($live_mode)"
else
  CKA_SIM_GRADE_FAILS+=("reported mode '$reported' does not match live mode '$live_mode'")
  err "reported mode '$reported' does not match live mode '$live_mode'"
  cka_sim::grade::record_trap kube-proxy-mode-mismatch-ipvs-iptables
fi

# Check reported value is a valid kube-proxy mode enum
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ "$reported" =~ ^(iptables|ipvs|nftables)$ ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("reported value '$reported' is a valid kube-proxy mode")
  ok "reported value '$reported' is a valid kube-proxy mode"
else
  CKA_SIM_GRADE_FAILS+=("reported value '$reported' is not a valid kube-proxy mode (expected iptables|ipvs|nftables)")
  err "reported value '$reported' is not a valid kube-proxy mode"
  cka_sim::grade::record_trap kube-proxy-mode-mismatch-ipvs-iptables
fi

cka_sim::grade::emit_result
