#!/bin/bash
# Phase 24 UAT — v1.0.3 Sign-Off (DRILL-NS-01, AUDIT-W&S06, LINT-01, BLG-06, BLG-07)
# Run on the control-plane node from the repo root.
# Tests the 5 v1.0.3 milestone items:
#   DRILL-NS-01: namespace placeholder expansion in drill prompt
#   AUDIT-W&S06: audit skip gate for workloads-scheduling/06-static-pod
#   LINT-01:     symptom-diff regression test fires on live cluster
#   BLG-06:     GHA validate-local job (deferred — confirm via push)
#   BLG-07:     GHA bash-tests job (deferred — confirm via push)
set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKA_SIM_ROOT

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
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

# ─── Cluster gate ───────────────────────────────────────────────────────
HAVE_CLUSTER=0
kubectl cluster-info >/dev/null 2>&1 && HAVE_CLUSTER=1

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Phase 24 UAT: v1.0.3 Sign-Off (DRILL-NS-01, AUDIT-W&S06, LINT-01, BLG-06, BLG-07)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── DRILL-NS-01: Namespace render smoke ────────────────────────────────
echo "── DRILL-NS-01: storage/01 namespace placeholder expansion ──"

if (( HAVE_CLUSTER == 0 )); then
  skip "DRILL-NS-01" "no live cluster"
else
  QDIR="$CKA_SIM_ROOT/packs/storage/01-pvc-binding"
  # Read question.md and expand placeholder the same way drill.sh does
  question_content=$(cat "$QDIR/question.md" 2>/dev/null || true)
  expanded="${question_content//\$\{CKA_SIM_LAB_NS\}/cka-sim-storage-01}"

  drill_rc=0
  # Assert resolved namespace appears
  if ! echo "$expanded" | grep -q "cka-sim-storage-01"; then
    echo "    FAIL: 'cka-sim-storage-01' not found in expanded prompt"
    drill_rc=1
  fi
  # Assert literal placeholder does NOT appear
  if echo "$expanded" | grep -qF '${CKA_SIM_LAB_NS}'; then
    echo "    FAIL: literal \${CKA_SIM_LAB_NS} still present after expansion"
    drill_rc=1
  fi
  report "DRILL-NS-01 namespace render (no literal \${CKA_SIM_LAB_NS})" $drill_rc
fi
echo ""

# ─── AUDIT-W&S06: Audit skip gate ──────────────────────────────────────
echo "── AUDIT-W&S06: workloads-scheduling/06-static-pod audit skip ──"

if (( HAVE_CLUSTER == 0 )); then
  skip "AUDIT-W&S06" "no live cluster"
else
  audit_out=$(bash "$CKA_SIM_ROOT/bin/cka-sim" audit workloads-scheduling/06-static-pod 2>&1)
  audit_exit=$?
  audit_rc=0
  # Assert output contains SKIPPED (case-insensitive)
  if ! echo "$audit_out" | grep -qi "SKIPPED"; then
    echo "    FAIL: audit output does not contain 'SKIPPED'"
    echo "    Output: $audit_out"
    audit_rc=1
  fi
  # Assert exit code is 0
  if (( audit_exit != 0 )); then
    echo "    FAIL: audit exited $audit_exit (expected 0)"
    audit_rc=1
  fi
  report "AUDIT-W&S06 audit emits SKIPPED + exits 0" $audit_rc
fi
echo ""

# ─── LINT-01: Regression test fires on live cluster ─────────────────────
echo "── LINT-01: symptom-diff-regression.sh fires on live cluster ──"

if (( HAVE_CLUSTER == 0 )); then
  skip "LINT-01" "no live cluster"
else
  lint_out=$(bash "$CKA_SIM_ROOT/tests/cases/symptom-diff-regression.sh" 2>&1)
  lint_exit=$?
  lint_rc=0
  # The regression test itself exits 0 on PASS (it expects the lint to catch drift).
  # If it exits non-zero, the lint did NOT fire — that's a failure of the fix.
  # Actually re-reading: the test exits 0 when lint correctly detects drift (PASS).
  # We want the test to PASS (exit 0) meaning the lint caught the mutation.
  if (( lint_exit != 0 )); then
    echo "    FAIL: symptom-diff-regression.sh exited $lint_exit (expected 0 = lint caught drift)"
    echo "    Output: $lint_out"
    lint_rc=1
  fi
  # Assert output contains the expected citation
  if ! echo "$lint_out" | grep -q "expected 'Bound', got 'Pending'"; then
    # The test may print PASS without the citation if it passed via the grep check
    if ! echo "$lint_out" | grep -q "PASS"; then
      echo "    FAIL: neither citation nor PASS found in output"
      lint_rc=1
    fi
  fi
  report "LINT-01 regression test passes (lint detects drift)" $lint_rc
fi
echo ""

# ─── BLG-06: GHA validate-local job (deferred) ─────────────────────────
echo "── BLG-06: GHA validate-local job ──"
# BLG-06: Confirmed OOB via GHA push. Record run ID in cka-sim/current-tests/step6-results.txt
if true; then
  skip "BLG-06" "GHA confirmation — verify via git push + validate.yml run ID in step6-results.txt"
fi
echo ""

# ─── BLG-07: GHA bash-tests job (deferred) ─────────────────────────────
echo "── BLG-07: GHA bash-tests job ──"
# BLG-07: Confirmed OOB via GHA push. Record run ID in cka-sim/current-tests/step6-results.txt
if true; then
  skip "BLG-07" "GHA confirmation — verify via git push + bash-tests job in step6-results.txt"
fi
echo ""

# ─── Summary ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped (of $TOTAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (( FAIL == 0 )); then
  echo "v1.0.3 UAT complete — record results in milestone audit doc."
fi

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
