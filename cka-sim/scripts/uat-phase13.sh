#!/bin/bash
# Phase 13 UAT — Grader Strengthening (BUG-M04, BUG-M05, BUG-M06)
# Run on the control-plane node from the repo root.
# Tests the 3 drills shipped under v1.0.1 milestone:
#   M04: services-networking/06-netpol-endport     (branched: 4 or 8 max)
#   M05: cluster-architecture/05-audit-policy      (4 weight=1 assertions)
#   M06: workloads-scheduling/04-hpa-metrics-server (7 weight=1 assertions)
set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKA_SIM_ROOT

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
# baseline.sh provides cka_sim::baseline::capture — required for graders that
# use assert_resource_candidate_authored / is_candidate_modified. The drill
# runner calls this between setup and grade; UAT drivers must do the same.
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
echo " Phase 13 UAT: Grader Strengthening (BUG-M04, M05, M06)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── BUG-M04: services-networking/06-netpol-endport ────────────────────
echo "── BUG-M04: services-networking/06-netpol-endport ──"

QDIR="$CKA_SIM_ROOT/packs/services-networking/06-netpol-endport"
NS="cka-sim-services-networking-06"
export CKA_SIM_LAB_NS="$NS"
SENTINEL="/tmp/q06-netpol-endport/.cni-enforces"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-M04" "directory not found"
else
  # 4.1 — setup writes CNI-enforcement sentinel; record branch
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "services-netpol-endport" || setup_rc=1
  sentinel_rc=1
  CNI_ENFORCES="unknown"
  if (( setup_rc == 0 )); then
    if [[ -f "$SENTINEL" ]]; then
      val=$(tr -d '[:space:]' < "$SENTINEL" 2>/dev/null)
      if [[ "$val" == "true" || "$val" == "false" ]]; then
        sentinel_rc=0
        CNI_ENFORCES="$val"
        echo -e "    sentinel: '$val' ${GREEN}OK${NC} ($([[ "$val" == "true" ]] && echo "max=8/8" || echo "max=4/4"))"
      else
        echo "    sentinel value not 'true' or 'false': '$val'"
      fi
    else
      echo "    sentinel file $SENTINEL missing"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "M04.1 setup writes CNI-enforcement sentinel (true|false)" $sentinel_rc

  # Compute expected max based on sentinel branch
  EXPECTED_MAX=4
  if [[ "$CNI_ENFORCES" == "true" ]]; then EXPECTED_MAX=8; fi

  # 4.2 — empty submission: 0/EXPECTED_MAX
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    if [[ "$got" == "0" && "$max" == "$EXPECTED_MAX" ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max} ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/${EXPECTED_MAX}; got ${got:-?}/${max:-?}"
    fi
  fi
  report "M04.2 empty submission scores 0/${EXPECTED_MAX}" $empty_rc

  # 4.3 — ref-solution: EXPECTED_MAX/EXPECTED_MAX
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  pass_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "$EXPECTED_MAX" && "$max" == "$EXPECTED_MAX" && "$traps" -eq 0 ]]; then
      pass_rc=0
      echo -e "    ref:   ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    ref-solution expected ${EXPECTED_MAX}/${EXPECTED_MAX} + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
      echo "    Output: $out"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "M04.3 ref-solution scores ${EXPECTED_MAX}/${EXPECTED_MAX} with 0 traps" $pass_rc

  # Stash the branch the test ran under for the regen task summary
  echo "    [info] Phase 13 fixture-regen target: services-networking__06-netpol-endport.sh (CNI=${CNI_ENFORCES})"

  reset_q "$QDIR"
fi
echo ""

# ─── BUG-M05: cluster-architecture/05-audit-policy ─────────────────────
echo "── BUG-M05: cluster-architecture/05-audit-policy ──"

QDIR="$CKA_SIM_ROOT/packs/cluster-architecture/05-audit-policy"
NS="cka-sim-cluster-architecture-05"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-M05" "directory not found"
else
  # 5.1 — empty/setup-stub submission: 0/4 + 1 trap
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "cluster-architecture-audit-policy" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "0" && "$max" == "4" && "$traps" -eq 1 ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/4 + 1 trap; got ${got:-?}/${max:-?} + ${traps} trap(s)"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "M05.1 empty (setup-stub) scores 0/4 with 1 trap" $empty_rc

  # 5.2 — ref-solution: 4/4 + 0 traps
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  pass_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "4" && "$max" == "4" && "$traps" -eq 0 ]]; then
      pass_rc=0
      echo -e "    ref:   ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    ref-solution expected 4/4 + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
      echo "    Output: $out"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "M05.2 ref-solution scores 4/4 with 0 traps" $pass_rc

  reset_q "$QDIR"
fi
echo ""

# ─── BUG-M06: workloads-scheduling/04-hpa-metrics-server ───────────────
echo "── BUG-M06: workloads-scheduling/04-hpa-metrics-server ──"

QDIR="$CKA_SIM_ROOT/packs/workloads-scheduling/04-hpa-metrics-server"
NS="cka-sim-workloads-scheduling-04"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-M06" "directory not found"
else
  # 6.1 — empty (no HPA): 0/7 (Assertion 1 fails the resource-authored gate;
  #       remaining six guarded behind that gate. Trap fires if metrics-server
  #       absent — count not asserted because cluster state is variable.)
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "workloads-hpa-metrics-server" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    if [[ "$got" == "0" && "$max" == "7" ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max} ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/7; got ${got:-?}/${max:-?}"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "M06.1 empty submission scores 0/7" $empty_rc

  # 6.2 — ref-solution: 7/7 (allow up to 60s for first metrics-server scrape;
  #       grade.sh has CKA_SIM_GRADE_TOP_RETRIES retry loop, but bump for first run)
  export CKA_SIM_GRADE_TOP_RETRIES=12
  export CKA_SIM_GRADE_TOP_SLEEP=5
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  pass_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "7" && "$max" == "7" && "$traps" -eq 0 ]]; then
      pass_rc=0
      echo -e "    ref:   ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    ref-solution expected 7/7 + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
      echo "    Output: $out"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "M06.2 ref-solution scores 7/7 with 0 traps (allows ≤60s scrape)" $pass_rc
  unset CKA_SIM_GRADE_TOP_RETRIES CKA_SIM_GRADE_TOP_SLEEP

  echo "    [info] Phase 13 fixture-regen target: workloads-scheduling__04-hpa-metrics-server.sh (0/5 → 0/7)"

  reset_q "$QDIR"
fi
echo ""

# ─── Summary ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped (of $TOTAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (( FAIL == 0 && SKIP == 0 )); then
  echo "All BUG-M04..M06 checks green — record in 13-UAT.md as 'pass'."
  echo ""
  echo "Next: regen 2 fixtures —"
  echo "  cka-sim/tests/cases/services-networking__06-netpol-endport.sh    (was 0/6, becomes 0/4 or 0/8 per CNI)"
  echo "  cka-sim/tests/cases/workloads-scheduling__04-hpa-metrics-server.sh (was 0/5, becomes 0/7)"
fi

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
