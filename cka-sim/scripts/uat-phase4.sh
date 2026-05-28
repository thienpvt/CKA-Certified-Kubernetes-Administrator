#!/bin/bash
# Phase 4 UAT — Live cluster verification
# Run on the control-plane node from the repo root.
# Tests: drill every question in storage + workloads-scheduling packs.
# For each question: reset → setup → grade (expect FAIL) → ref-solution → grade (expect PASS) → reset
set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKA_SIM_ROOT

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"

PASS=0 FAIL=0 TOTAL=0 SKIP=0

report() {
  local name="$1" rc="$2"
  (( TOTAL++ ))
  if (( rc == 0 )); then
    (( PASS++ ))
    echo -e "  ${GREEN}✓${NC} $name"
  else
    (( FAIL++ ))
    echo -e "  ${RED}✗${NC} $name"
  fi
}

skip() {
  local name="$1" reason="$2"
  (( TOTAL++ ))
  (( SKIP++ ))
  echo -e "  ${YELLOW}⊘${NC} $name — $reason"
}

run_question() {
  local pack="$1" q_path="$2"
  local qdir="$CKA_SIM_ROOT/packs/$pack/$q_path"
  local q_index="${q_path%%-*}"
  local ns="cka-sim-${pack}-${q_index}"
  export CKA_SIM_LAB_NS="$ns"

  if [[ ! -d "$qdir" ]]; then
    skip "$pack/$q_path" "directory not found"
    return
  fi

  echo -n "  $pack/$q_path: "

  # Reset
  bash "$qdir/reset.sh" 2>/dev/null || true
  sleep 3

  # Setup
  local setup_err
  setup_err=$(bash "$qdir/setup.sh" 2>&1)
  if (( $? != 0 )); then
    echo -e "${RED}FAIL${NC} (setup.sh failed)"
    echo "    stderr: ${setup_err:0:200}"
    report "$pack/$q_path" 1
    bash "$qdir/reset.sh" 2>/dev/null || true
    sleep 3
    return
  fi

  # Grade without solution — expect non-perfect score or traps
  local fail_out fail_rc
  fail_out=$(bash "$qdir/grade.sh" 2>/dev/null)
  fail_rc=$?
  local fail_traps
  fail_traps=$(echo "$fail_out" | grep -c "Trap " || true)
  local fail_score_line
  fail_score_line=$(echo "$fail_out" | grep "SCORE:" || true)

  # Apply reference solution
  local sol_err
  sol_err=$(bash "$qdir/ref-solution.sh" 2>&1)
  if (( $? != 0 )); then
    echo -e "${RED}FAIL${NC} (ref-solution.sh failed)"
    echo "    stderr: ${sol_err:0:200}"
    report "$pack/$q_path" 1
    bash "$qdir/reset.sh" 2>/dev/null || true
    sleep 3
    return
  fi

  # Grade with solution — expect PASS (score == max)
  local pass_out pass_rc
  pass_out=$(bash "$qdir/grade.sh" 2>/dev/null)
  pass_rc=$?
  local score_line
  score_line=$(echo "$pass_out" | grep "SCORE:" || true)

  local result_rc=0
  if [[ -z "$score_line" ]]; then
    echo -e "${RED}FAIL${NC} (no SCORE line after ref-solution)"
    result_rc=1
  else
    local scored got max
    scored=$(echo "$score_line" | sed 's/.*SCORE: \([0-9]*\)\/\([0-9]*\).*/\1 \2/')
    got=$(echo "$scored" | cut -d' ' -f1)
    max=$(echo "$scored" | cut -d' ' -f2)
    if (( got == max )); then
      echo -e "${GREEN}PASS${NC} (pre-fix: ${fail_traps} traps, post-fix: $got/$max)"
    else
      echo -e "${RED}FAIL${NC} (expected $max/$max, got $got/$max)"
      echo "    Output: $pass_out"
      result_rc=1
    fi
  fi

  report "$pack/$q_path" $result_rc

  # Cleanup
  bash "$qdir/reset.sh" 2>/dev/null || true
  sleep 3
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Phase 4 UAT: Storage + Workloads-Scheduling Packs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── Storage Pack (6 questions) ─────────────────────────────────────────
echo "── Storage Pack ──"
echo ""

STORAGE_QUESTIONS=(
  "01-pvc-binding"
  "02-storageclass-dynamic"
  "03-access-modes-reclaim"
  "04-csi-volumesnapshot"
  "05-wait-for-first-consumer"
  "06-pvc-mount-pod"
)

for q in "${STORAGE_QUESTIONS[@]}"; do
  run_question "storage" "$q"
done

echo ""

# ─── Workloads-Scheduling Pack (8 questions) ────────────────────────────
echo "── Workloads-Scheduling Pack ──"
echo ""

WORKLOADS_QUESTIONS=(
  "01-deployment-requests"
  "02-rolling-update-rollback"
  "03-configmap-secret-env-volume"
  "04-hpa-metrics-server"
  "05-daemonset"
  "06-static-pod"
  "07-native-sidecar"
  "08-nodeselector-affinity-taints"
)

for q in "${WORKLOADS_QUESTIONS[@]}"; do
  run_question "workloads-scheduling" "$q"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped (of $TOTAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
