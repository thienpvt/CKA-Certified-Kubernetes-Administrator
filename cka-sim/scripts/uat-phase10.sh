#!/bin/bash
# Phase 10 UAT — HIGH Single-Question Edits (BUG-H01..H04)
# Run on the control-plane node from the repo root.
# Tests the 4 drills shipped under v1.0.1 milestone:
#   H01: storage/01-pvc-binding              (symptom rewrite + Pod consumer)
#   H02: services-networking/05-kube-proxy-mode (SEED_MODE=placeholder)
#   H03: cluster-architecture/04-pss-enforce  (file-based dry-run grader)
#   H04: cluster-architecture/08-priorityclass (allowed-set instead of hard-pin)
set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKA_SIM_ROOT

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
# baseline.sh provides cka_sim::baseline::capture — required for graders that
# use assert_resource_candidate_authored / is_candidate_modified. The drill
# runner calls this between setup and grade; UAT drivers must do the same.
# Phase 10 graders don't currently use these helpers, so this is hygiene —
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

# ─── Helpers ────────────────────────────────────────────────────────────
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
echo " Phase 10 UAT: HIGH Single-Question Edits (BUG-H01..H04)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── BUG-H01: storage/01-pvc-binding ────────────────────────────────────
echo "── BUG-H01: storage/01-pvc-binding ──"

QDIR="$CKA_SIM_ROOT/packs/storage/01-pvc-binding"
NS="cka-sim-storage-01"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-H01" "directory not found"
else
  # 1.1 — symptom rewrite: question.md must NOT claim PVC is stuck Pending
  symptom_check_rc=0
  if grep -qE "PVC.*(stuck|Pending)" "$QDIR/question.md" 2>/dev/null \
     && ! grep -qiE "(Pod|q01-app-consumer).*(schedule|fails to schedule)" "$QDIR/question.md" 2>/dev/null; then
    echo "    question.md still describes 'PVC stuck Pending' without Pod-scheduling rewrite"
    symptom_check_rc=1
  fi
  report "H01.1 question.md symptom claim points at Pod scheduling" $symptom_check_rc

  # 1.2 — empty submission: 0/3 + ≥1 trap
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "storage-pvc-binding" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "0" && "$max" == "3" && "$traps" -ge 1 ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/3 + ≥1 trap; got ${got:-?}/${max:-?} + ${traps} trap(s)"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "H01.2 empty submission scores 0/3 with hostpath-pv trap" $empty_rc

  # 1.3 — ref-solution: 3/3 + 0 traps
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
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "H01.3 ref-solution scores 3/3 with 0 traps" $pass_rc

  reset_q "$QDIR"
fi
echo ""

# ─── BUG-H02: services-networking/05-kube-proxy-mode ───────────────────
echo "── BUG-H02: services-networking/05-kube-proxy-mode ──"

QDIR="$CKA_SIM_ROOT/packs/services-networking/05-kube-proxy-mode"
NS="cka-sim-services-networking-05"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-H02" "directory not found"
else
  # 2.1 — setup writes seeded mode = 'placeholder'
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "services-kube-proxy-mode" || setup_rc=1
  seed_rc=1
  seed_file="/tmp/q05-kube-proxy/.setup-seeded-mode"
  if [[ -f "$seed_file" ]]; then
    seeded=$(tr -d '[:space:]' < "$seed_file" 2>/dev/null)
    if [[ "$seeded" == "placeholder" ]]; then
      seed_rc=0
      echo -e "    seeded mode: 'placeholder' ${GREEN}OK${NC}"
    else
      echo "    seeded mode expected 'placeholder'; got '$seeded'"
    fi
  else
    echo "    seed file $seed_file missing"
  fi
  report "H02.1 setup seeds SEED_MODE='placeholder'" $seed_rc

  # 2.2 — empty submission: 0/3
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    if [[ "$got" == "0" && "$max" == "3" ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max} ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/3; got ${got:-?}/${max:-?}"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "H02.2 empty submission scores 0/3" $empty_rc

  # 2.3 — ref-solution: 3/3 (any cluster mode — including ipvs, the previously-broken case)
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  pass_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    if [[ "$got" == "3" && "$max" == "3" ]]; then
      pass_rc=0
      echo -e "    ref:   ${got}/${max} ${GREEN}OK${NC}"
    else
      echo "    ref-solution expected 3/3; got ${got:-?}/${max:-?}"
      echo "    Output: $out"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "H02.3 ref-solution scores 3/3 on this cluster's proxy mode" $pass_rc

  reset_q "$QDIR"
fi
echo ""

# ─── BUG-H03: cluster-architecture/04-pss-enforce ──────────────────────
echo "── BUG-H03: cluster-architecture/04-pss-enforce ──"

QDIR="$CKA_SIM_ROOT/packs/cluster-architecture/04-pss-enforce"
NS="cka-sim-cluster-architecture-04"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-H03" "directory not found"
else
  # 3.1 — ref-solution.sh does NOT kubectl apply the candidate Pod
  #       (only the BUG-H03 explanatory comment block remains)
  ref_apply_rc=0
  if grep -E '^\s*kubectl\s+apply' "$QDIR/ref-solution.sh" 2>/dev/null \
     | grep -v '^[[:space:]]*#' >/dev/null; then
    echo "    ref-solution.sh contains a non-comment 'kubectl apply' line — re-introduces BUG-H03"
    ref_apply_rc=1
  fi
  report "H03.1 ref-solution.sh has no live kubectl apply for candidate Pod" $ref_apply_rc

  # 3.2 — empty submission: 0/5 + 2 traps
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "cluster-architecture-pss-enforce" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "0" && "$max" == "5" && "$traps" -eq 2 ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/5 + 2 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "H03.2 empty submission scores 0/5 with 2 traps" $empty_rc

  # 3.3 — ref-solution: 5/5 + 0 traps
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  pass_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "5" && "$max" == "5" && "$traps" -eq 0 ]]; then
      pass_rc=0
      echo -e "    ref:   ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    ref-solution expected 5/5 + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
      echo "    Output: $out"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "H03.3 ref-solution scores 5/5 with 0 traps" $pass_rc

  reset_q "$QDIR"
fi
echo ""

# ─── BUG-H04: cluster-architecture/08-priorityclass ────────────────────
echo "── BUG-H04: cluster-architecture/08-priorityclass ──"

QDIR="$CKA_SIM_ROOT/packs/cluster-architecture/08-priorityclass"
NS="cka-sim-cluster-architecture-08"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-H04" "directory not found"
else
  # 4.1 — empty submission: 0/2 + 1 trap (deduped)
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "cluster-architecture-priorityclass" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "0" && "$max" == "2" && "$traps" -ge 1 ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/2 + ≥1 trap; got ${got:-?}/${max:-?} + ${traps} trap(s)"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "H04.1 empty submission scores 0/2 with priorityclass trap" $empty_rc

  # 4.2 — flip q08-critical only (ref-solution path): 2/2 + 0 traps
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  flipA_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "2" && "$max" == "2" && "$traps" -eq 0 ]]; then
      flipA_rc=0
      echo -e "    flip q08-critical: ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    flip q08-critical expected 2/2 + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "H04.2 flip q08-critical scores 2/2 (preserved path)" $flipA_rc

  # 4.3 — flip q08-batch only (THE PREVIOUSLY BROKEN PATH): 2/2 + 0 traps
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup2_rc=$?
  flipB_rc=1
  if (( setup2_rc == 0 )); then
    kubectl patch priorityclass q08-batch --type=merge -p '{"globalDefault":true}' >/dev/null 2>&1
    sleep 5
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "2" && "$max" == "2" && "$traps" -eq 0 ]]; then
      flipB_rc=0
      echo -e "    flip q08-batch:    ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC} (BUG-H04 fix)"
    else
      echo "    flip q08-batch expected 2/2 + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
      echo "    Output: $out"
    fi
  fi
  report "H04.3 flip q08-batch scores 2/2 (BUG-H04 success criterion)" $flipB_rc

  reset_q "$QDIR"
fi
echo ""

# ─── Summary ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped (of $TOTAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Hint for UAT.md update
if (( FAIL == 0 && SKIP == 0 )); then
  echo "All BUG-H01..H04 checks green — record in 10-UAT.md as 'pass'."
fi

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
