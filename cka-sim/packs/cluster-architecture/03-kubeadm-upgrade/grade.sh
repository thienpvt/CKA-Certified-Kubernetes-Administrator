#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

sandbox="/tmp/q03-kubeadm-upgrade"
plan="$sandbox/planned-upgrade.txt"
script="$sandbox/apply-script.sh"

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -s "$plan" ]]; then CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 )); ok "planned-upgrade.txt written"; else CKA_SIM_GRADE_FAILS+=("planned-upgrade.txt empty"); err "planned-upgrade.txt empty"; fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if grep -qE 'v1\.35' "$plan" 2>/dev/null; then CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 )); ok "plan names v1.35"; else CKA_SIM_GRADE_FAILS+=("plan does not name v1.35"); err "plan does not name v1.35"; fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if grep -q 'kubeadm upgrade plan' "$script" 2>/dev/null; then CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 )); ok "script runs kubeadm upgrade plan"; else CKA_SIM_GRADE_FAILS+=("script missing kubeadm upgrade plan"); err "script missing kubeadm upgrade plan"; cka_sim::grade::record_trap kubeadm-upgrade-skip-plan; fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if grep -qE 'kubeadm upgrade apply v1\.35' "$script" 2>/dev/null; then CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 )); ok "script applies v1.35"; else CKA_SIM_GRADE_FAILS+=("script missing kubeadm upgrade apply v1.35"); err "script missing kubeadm upgrade apply v1.35"; fi

plan_line=$(grep -n 'kubeadm upgrade plan' "$script" 2>/dev/null | head -1 | cut -d: -f1)
apply_line=$(grep -n 'kubeadm upgrade apply' "$script" 2>/dev/null | head -1 | cut -d: -f1)
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -n "$plan_line" && -n "$apply_line" && "$plan_line" -lt "$apply_line" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "plan step appears before apply"
else
  CKA_SIM_GRADE_FAILS+=("plan step must appear before apply")
  err "plan step must appear before apply"
  cka_sim::grade::record_trap kubeadm-upgrade-skip-plan
fi

cka_sim::grade::emit_result
