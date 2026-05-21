#!/bin/bash
# Phase 18-21 UAT — v1.0.2 Forensic Closure (BUG-H07, BUG-H08, BUG-M11, BUG-M12)
# Run on the control-plane node from the repo root.
# Tests the 4 drills shipped under v1.0.2 milestone:
#   H07 (Phase 19.1): troubleshooting/05-static-pod-manifest (locale-safe grep)
#   H08 (Phase 19.2): cluster-architecture/05-audit-policy   (4 weight=1 assertions)
#   M11 (Phase 20.1): cluster-architecture/04-pss-enforce    (PSS label scalar via audit)
#   M12 (Phase 20.2): exam-mode report_golden                (LF-only fixture)
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
echo " Phase 18-21 UAT: v1.0.2 Forensic Closure (BUG-H07, H08, M11, M12)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── BUG-H07: troubleshooting/05-static-pod-manifest ────────────────────
# Phase 19.1 — locale-safe grep. setup.sh must succeed under LC_ALL=C.
echo "── BUG-H07: troubleshooting/05-static-pod-manifest (Phase 19.1) ──"

QDIR="$CKA_SIM_ROOT/packs/troubleshooting/05-static-pod-manifest"
NS="cka-sim-troubleshooting-05"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-H07" "directory not found"
else
  # 7.1 — grep -F shape (locale-independent). No -P remains in setup.sh.
  fix_present_rc=0
  if grep -nE "grep[[:space:]]+-P" "$QDIR/setup.sh" >/dev/null 2>&1; then
    echo "    setup.sh still contains 'grep -P' (locale-fragile) — re-introduces BUG-H07"
    fix_present_rc=1
  fi
  if ! grep -nE "grep[[:space:]]+-F[[:space:]]+\\\$'\\\\t'" "$QDIR/setup.sh" >/dev/null 2>&1; then
    # shellcheck disable=SC2028  # rationale: literal escape sequences in echo are user-facing text showing the exact grep pattern
    echo "    setup.sh missing 'grep -F \$'\\\\t'' (the locale-safe shape)"
    fix_present_rc=1
  fi
  report "H07.1 setup.sh uses locale-safe 'grep -F \$'\\\\t'' (no -P)" $fix_present_rc

  # 7.2 — setup.sh exits 0 under LC_ALL=C (the failure mode reported by GHA)
  reset_q "$QDIR"
  setup_rc=0
  LC_ALL=C bash "$QDIR/setup.sh" >/dev/null 2>&1 || setup_rc=$?
  if (( setup_rc == 0 )); then
    echo -e "    LC_ALL=C bash setup.sh: rc=0 ${GREEN}OK${NC}"
  else
    echo "    LC_ALL=C bash setup.sh: rc=$setup_rc (expected 0)"
  fi
  report "H07.2 setup.sh exits 0 under LC_ALL=C" $setup_rc

  # 7.3 — empty submission: 0/N + ≥0 traps (the question.md scoring contract)
  prep_baseline "$NS" "troubleshooting-static-pod-manifest" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    if [[ "$got" == "0" ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max} ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/N; got ${got:-?}/${max:-?}"
    fi
  fi
  report "H07.3 empty submission scores 0/N" $empty_rc

  # 7.4 — ref-solution: max/max + 0 traps
  bash "$QDIR/ref-solution.sh" >/dev/null 2>&1
  ref_rc=$?
  pass_rc=1
  if (( ref_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    traps=$(trap_count "$out")
    if [[ "$got" == "$max" && "$max" != "" && "$traps" -eq 0 ]]; then
      pass_rc=0
      echo -e "    ref:   ${got}/${max}, ${traps} trap(s) ${GREEN}OK${NC}"
    else
      echo "    ref-solution expected max/max + 0 traps; got ${got:-?}/${max:-?} + ${traps} trap(s)"
      echo "    Output: $out"
    fi
  else
    echo "    ref-solution.sh failed (rc=$ref_rc)"
  fi
  report "H07.4 ref-solution scores max/max with 0 traps" $pass_rc

  reset_q "$QDIR"
fi
echo ""

# ─── BUG-H08: cluster-architecture/05-audit-policy ──────────────────────
# Phase 19.2 — audit-policy case-file aligned to grader's 4 weight=1 assertions.
# Per FORENSIC-v102 closure note: empty 0/4, ref 4/4 (no setup-state stub branch).
echo "── BUG-H08: cluster-architecture/05-audit-policy (Phase 19.2) ──"

QDIR="$CKA_SIM_ROOT/packs/cluster-architecture/05-audit-policy"
NS="cka-sim-cluster-architecture-05"
export CKA_SIM_LAB_NS="$NS"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-H08" "directory not found"
else
  # 8.1 — empty submission: 0/4 (4 weight=1 assertions, all fail without policy.yaml edits)
  reset_q "$QDIR"
  bash "$QDIR/setup.sh" >/dev/null 2>&1
  setup_rc=$?
  prep_baseline "$NS" "cluster-architecture-audit-policy" || setup_rc=1
  empty_rc=1
  if (( setup_rc == 0 )); then
    out=$(bash "$QDIR/grade.sh" 2>/dev/null)
    s=$(score_of "$out"); got="${s%% *}"; max="${s##* }"
    if [[ "$got" == "0" && "$max" == "4" ]]; then
      empty_rc=0
      echo -e "    empty: ${got}/${max} ${GREEN}OK${NC}"
    else
      echo "    empty submission expected 0/4; got ${got:-?}/${max:-?}"
    fi
  else
    echo "    setup.sh failed (rc=$setup_rc)"
  fi
  report "H08.1 empty submission scores 0/4 (case-file aligned to 4 assertions)" $empty_rc

  # 8.2 — ref-solution: 4/4 + 0 traps
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
  report "H08.2 ref-solution scores 4/4 with 0 traps" $pass_rc

  reset_q "$QDIR"
fi
echo ""

# ─── BUG-M11: cluster-architecture/04-pss-enforce ───────────────────────
# Phase 20.1 — symptom-diff jq `as $v` binding fix. Verified via audit harness
# (the symptom-diff codepath the bug lived on), not via grade.sh which is
# already covered by Phase 10's H03 UAT.
echo "── BUG-M11: cluster-architecture/04-pss-enforce (Phase 20.1) ──"

QDIR="$CKA_SIM_ROOT/packs/cluster-architecture/04-pss-enforce"

if [[ ! -d "$QDIR" ]]; then
  skip "BUG-M11" "directory not found"
elif ! command -v "$CKA_SIM_ROOT/bin/cka-sim" >/dev/null 2>&1 \
   && [[ ! -x "$CKA_SIM_ROOT/bin/cka-sim" ]]; then
  skip "BUG-M11" "cka-sim binary missing or not executable"
else
  # 11.1 — audit harness reports PASS (n/n) for the question. This exercises
  #        symptom-diff.sh's _jsonpath_to_jq dotted-segment branch on real labels.
  audit_rc=1
  audit_out=$(bash "$CKA_SIM_ROOT/bin/cka-sim" audit cluster-architecture/04-pss-enforce 2>&1)
  if echo "$audit_out" | grep -qE "✓ cluster-architecture/04-pss-enforce: PASS"; then
    audit_rc=0
    line=$(echo "$audit_out" | grep -E "cluster-architecture/04-pss-enforce" | head -1)
    echo -e "    audit: ${GREEN}OK${NC} — $line"
  else
    echo "    audit did not return PASS for cluster-architecture/04-pss-enforce"
    echo "    Output: $audit_out"
  fi
  report "M11.1 cka-sim audit cluster-architecture/04-pss-enforce returns PASS (n/n)" $audit_rc
fi
echo ""

# ─── BUG-M12: exam-mode report_golden test ──────────────────────────────
# Phase 20.2 — expected-report.md regenerated LF-only + .gitattributes rule.
# Verified via the unit-test runner (the failure mode reported on GHA Linux).
echo "── BUG-M12: exam-mode report_golden (Phase 20.2) ──"

if [[ ! -x "$CKA_SIM_ROOT/scripts/test.sh" ]]; then
  skip "BUG-M12" "scripts/test.sh missing or not executable"
else
  # 12.1 — report_golden case passes
  report_rc=1
  report_out=$(bash "$CKA_SIM_ROOT/scripts/test.sh" 2>&1 | grep -E "report_golden" || true)
  if echo "$report_out" | grep -qE "✓ case passed: report_golden"; then
    report_rc=0
    echo -e "    report_golden: ${GREEN}OK${NC} — $(echo "$report_out" | grep "case passed" | head -1)"
  else
    echo "    report_golden did not report 'case passed'"
    echo "    Output: $report_out"
  fi
  report "M12.1 unit-test 'report_golden' case passes (LF-only fixture)" $report_rc

  # 12.2 — fixture is LF-only (no \r in expected-report.md)
  fixture="$CKA_SIM_ROOT/tests/fixtures/exam/expected-report.md"
  fixture_rc=1
  if [[ -f "$fixture" ]]; then
    if grep -lU $'\r' "$fixture" >/dev/null 2>&1; then
      echo "    fixture $fixture contains CRLF — re-introduces BUG-M12"
    else
      fixture_rc=0
      echo -e "    fixture LF-only: ${GREEN}OK${NC}"
    fi
  else
    echo "    fixture $fixture not found"
  fi
  report "M12.2 expected-report.md is LF-only" $fixture_rc
fi
echo ""

# ─── Summary ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped (of $TOTAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (( FAIL == 0 && SKIP == 0 )); then
  echo "All BUG-H07, H08, M11, M12 checks green — record in FORENSIC-v102.md"
  echo "Closure Status table with closed-by: <commit-sha-of-this-uat-run>."
fi

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
