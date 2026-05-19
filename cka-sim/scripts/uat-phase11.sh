#!/bin/bash
# Phase 11 UAT — HIGH Grader/Question Rework (BUG-H05, BUG-H06)
# Run on the control-plane node from the repo root.
# Tests the 2 drills shipped under v1.0.1 milestone:
#   H05: troubleshooting/04-debug-node          (forgeable label gate dropped)
#   H06: troubleshooting/05-static-pod-manifest (question reframed to match grader)
set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKA_SIM_ROOT

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
# baseline.sh provides cka_sim::baseline::capture — required for graders that
# use assert_resource_candidate_authored / is_candidate_modified. The drill
# runner calls this between setup and grade; UAT drivers must do the same.
# Phase 11 graders don't currently use these helpers, so this is hygiene —
# future drills added to these packs would silently mis-score without it.
source "$CKA_SIM_ROOT/lib/baseline.sh"

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

score_of() {
  echo "$1" | grep "SCORE:" | sed 's/.*SCORE: \([0-9]*\)\/\([0-9]*\).*/\1 \2/' | head -1
}

trap_count() {
  echo "$1" | grep -c "Trap " || true
}

reset_q() {
  bash "$1/reset.sh" >/dev/null 2>&1 || true
  sleep 3
}

# prep_baseline — mirrors lib/cmd/drill.sh:309-318. Runner-managed step that
# graders depend on (assert_resource_candidate_authored / is_candidate_modified).
# Setup scripts do NOT call this themselves.
#
# Usage: prep_baseline <ns> <question-id>
prep_baseline() {
  local ns="$1" qid="$2"
  export CKA_SIM_QUESTION_ID="$qid"
  export CKA_SIM_BASELINE_PATH="/tmp/cka-sim/${qid}/baseline.json"
  mkdir -p "$(dirname "$CKA_SIM_BASELINE_PATH")"
  sleep 1
  cka_sim::baseline::capture "$ns" >/dev/null 2>&1 || {
    echo "    baseline capture failed for ns=$ns qid=$qid"
    return 1
  }
  return 0
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Phase 11 UAT: HIGH Grader/Question Rework (BUG-H05, BUG-H06)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── BUG-H05: troubleshooting/04-debug-node ────────────────────────────
echo "── BUG-H05: troubleshooting/04-debug-node ──"

QDIR="$CKA_SIM_ROOT/packs/troubleshooting/04-debug-node"
NS="cka-sim-troubleshooting-04"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-H05" "directory not found"
else
  # 5.1 — ref-solution.sh manifest no longer carries the forgeable
  #       'kubectl.kubernetes.io/debug-source' label
  ref_label_rc=0
  if grep -q 'kubectl.kubernetes.io/debug-source' "$QDIR/ref-solution.sh" 2>/dev/null; then
    echo "    ref-solution.sh still references kubectl.kubernetes.io/debug-source — forgeable label not removed"
    ref_label_rc=1
  fi
  report "H05.1 ref-solution Pod no longer carries debug-source label" $ref_label_rc

  # 5.2 — question.md authorizes any K8s-native node-introspection technique
  q_text_rc=0
  if ! grep -qiE "(kubectl debug node|any.*Kubernetes-native|hand-rolled|ephemeral debug)" "$QDIR/question.md" 2>/dev/null; then
    echo "    question.md does not mention authorized alternative techniques"
    q_text_rc=1
  fi
  if ! grep -q "answer.txt" "$QDIR/question.md" 2>/dev/null; then
    echo "    question.md does not state grader scores answer.txt"
    q_text_rc=1
  fi
  report "H05.2 question.md authorizes any K8s-native technique + scores answer.txt only" $q_text_rc

  # 5.3 — empty submission: 0/1, 0 traps (no debug-source pod, no ephemeral)
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "troubleshooting-debug-node" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "0" && "$max" == "1" && "$traps" -eq 0 ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/1 + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "H05.3 empty submission scores 0/1 with 0 traps" $empty_rc

  # 5.4 — ref-solution: 1/1, 0 traps (label-free privileged Pod path)
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  pass_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "1" && "$max" == "1" && "$traps" -eq 0 ]]; then
      pass_rc=0
      echo -e "    ref:   ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    ref-solution expected 1/1 + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
      echo "    Output: $out"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "H05.4 ref-solution scores 1/1 (answer matches kernelVersion)" $pass_rc

  reset_q "$QDIR"
fi
echo ""

# ─── BUG-H06: troubleshooting/05-static-pod-manifest ───────────────────
echo "── BUG-H06: troubleshooting/05-static-pod-manifest ──"

QDIR="$CKA_SIM_ROOT/packs/troubleshooting/05-static-pod-manifest"
NS="cka-sim-troubleshooting-05"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-H06" "directory not found"
else
  # 6.1 — question.md no longer claims the kubelet-pickup / Running framing
  q_text_rc=0
  if grep -qiE "(never (becomes|reaches) Running|Pod.*never appears|kubelet.*picks it up)" "$QDIR/question.md" 2>/dev/null; then
    echo "    question.md still uses the kubelet-Running framing the grader does not check"
    q_text_rc=1
  fi
  if ! grep -qiE "(grader scores the file|client dry-run|dry-run=client)" "$QDIR/question.md" 2>/dev/null; then
    echo "    question.md does not state the grader scores the file (no Running wait)"
    q_text_rc=1
  fi
  report "H06.1 question.md reframed to file-based grading (no Running wait)" $q_text_rc

  # 6.2 — empty submission (broken tab-indent variant): 0/3 + 1 dedup trap
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "troubleshooting-static-pod-manifest" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "0" && "$max" == "3" && "$traps" -eq 1 ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/3 + 1 trap; got ${got:-?}/${max:-?} + ${traps} trap(s)"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "H06.2 empty submission scores 0/3 with 1 dedup trap" $empty_rc

  # 6.3 — ref-solution: 3/3 + 0 traps
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  pass_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "3" && "$max" == "3" && "$traps" -eq 0 ]]; then
      pass_rc=0
      echo -e "    ref:   ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    ref-solution expected 3/3 + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
      echo "    Output: $out"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "H06.3 ref-solution scores 3/3 with 0 traps" $pass_rc

  reset_q "$QDIR"
fi
echo ""

# ─── Summary ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped (of $TOTAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (( FAIL == 0 && SKIP == 0 )); then
  echo "All BUG-H05..H06 checks green — record in 11-UAT.md as 'pass'."
fi

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
