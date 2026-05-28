#!/bin/bash
# Phase 3 UAT — Live cluster verification
# Run on the control-plane node from the repo root.
# Tests: drill single question, idempotency (TRIP-02), 5-domain round-trip.
set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CKA_SIM_ROOT

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"

PASS=0 FAIL=0 TOTAL=0

report() {
  local name="$1" rc="$2"
  (( TOTAL++ ))
  if (( rc == 0 )); then
    (( PASS++ ))
    echo -e "${GREEN}✓${NC} $name"
  else
    (( FAIL++ ))
    echo -e "${RED}✗${NC} $name"
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Phase 3 UAT: Runtime Contract + Drill Mode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── Test 1: Drill command runs a single question ───────────────────────
echo "── Test 1: Drill Command Runs a Single Question ──"
echo "   Running setup + grade (no solution) on storage Q1..."

PACK="storage"
Q_DIR="$CKA_SIM_ROOT/packs/storage/01-pvc-binding"
NS="cka-sim-storage-01"
export CKA_SIM_LAB_NS="$NS"

# Reset first
bash "$Q_DIR/reset.sh" 2>/dev/null || true
sleep 3

# Setup
bash "$Q_DIR/setup.sh"
setup_rc=$?

# Grade without solution — expect FAIL + trap lines
grade_out=$(bash "$Q_DIR/grade.sh" 2>/dev/null)
grade_rc=$?

has_score=$(echo "$grade_out" | grep -c "SCORE:" || true)
has_trap=$(echo "$grade_out" | grep -c "Trap " || true)

t1_rc=0
if (( setup_rc != 0 )); then
  echo "   FAIL: setup.sh exited non-zero ($setup_rc)"
  t1_rc=1
elif (( has_score == 0 )); then
  echo "   FAIL: no SCORE: line in grade output"
  echo "   Output: $grade_out"
  t1_rc=1
elif (( has_trap == 0 )); then
  echo "   FAIL: no Trap line in grade output (expected ≥1 for wrong solution)"
  echo "   Output: $grade_out"
  t1_rc=1
else
  echo "   Grade output: $grade_out"
fi
report "Drill runs single question (SCORE + Trap emitted)" $t1_rc

# Cleanup
bash "$Q_DIR/reset.sh" 2>/dev/null || true
sleep 3

echo ""

# ─── Test 2: Idempotent re-run (TRIP-02) ───────────────────────────────
echo "── Test 2: Idempotent Re-run (TRIP-02) ──"
echo "   Running setup twice in a row on storage Q1..."

export CKA_SIM_LAB_NS="$NS"

bash "$Q_DIR/setup.sh" > /dev/null 2>&1
first_rc=$?

# Run setup again immediately — should NOT produce AlreadyExists errors
setup2_err=$(bash "$Q_DIR/setup.sh" 2>&1)
second_rc=$?
already_exists=$(echo "$setup2_err" | grep -ci "AlreadyExists" || true)

t2_rc=0
if (( first_rc != 0 )); then
  echo "   FAIL: first setup exited non-zero ($first_rc)"
  t2_rc=1
elif (( second_rc != 0 )); then
  echo "   FAIL: second setup exited non-zero ($second_rc)"
  t2_rc=1
elif (( already_exists > 0 )); then
  echo "   FAIL: AlreadyExists errors on second run"
  echo "   Stderr: $setup2_err"
  t2_rc=1
fi
report "Idempotent re-run (no AlreadyExists)" $t2_rc

bash "$Q_DIR/reset.sh" 2>/dev/null || true
sleep 3

echo ""

# ─── Test 3: 5-domain reference question round-trip ─────────────────────
echo "── Test 3: Reference Questions Round-Trip (5 domains) ──"
echo "   For each domain: setup → grade (expect FAIL) → ref-solution → grade (expect PASS)"
echo ""

declare -A DOMAIN_QUESTIONS=(
  [storage]="01-pvc-binding"
  [workloads-scheduling]="01-deployment-requests"
  [services-networking]="01-clusterip-service"
  [cluster-architecture]="01-rbac-viewer"
  [troubleshooting]="01-deploy-svc-mismatch"
)

t3_rc=0
for domain in storage workloads-scheduling services-networking cluster-architecture troubleshooting; do
  q="${DOMAIN_QUESTIONS[$domain]}"
  qdir="$CKA_SIM_ROOT/packs/$domain/$q"

  if [[ ! -d "$qdir" ]]; then
    echo "   SKIP: $domain/$q — directory not found"
    continue
  fi

  # Derive namespace from pack + question index
  q_index="${q%%-*}"  # e.g. "01"
  ns="cka-sim-${domain}-${q_index}"
  export CKA_SIM_LAB_NS="$ns"

  echo -n "   $domain/$q: "

  # Reset
  bash "$qdir/reset.sh" 2>/dev/null || true
  sleep 3

  # Setup
  bash "$qdir/setup.sh" > /dev/null 2>&1
  if (( $? != 0 )); then
    echo -e "${RED}FAIL${NC} (setup failed)"
    t3_rc=1
    continue
  fi

  # Grade without solution — expect non-zero rc or SCORE < max
  fail_out=$(bash "$qdir/grade.sh" 2>/dev/null)
  fail_rc=$?
  fail_traps=$(echo "$fail_out" | grep -c "Trap " || true)

  if (( fail_rc == 0 )) && (( fail_traps == 0 )); then
    # Check if score is perfect (shouldn't be without solution)
    score_line=$(echo "$fail_out" | grep "SCORE:" || true)
    if [[ -n "$score_line" ]]; then
      scored=$(echo "$score_line" | sed 's/.*SCORE: \([0-9]*\)\/\([0-9]*\).*/\1 \2/')
      got=$(echo "$scored" | cut -d' ' -f1)
      max=$(echo "$scored" | cut -d' ' -f2)
      if (( got == max )); then
        echo -e "${RED}FAIL${NC} (grade PASSED without solution — expected FAIL)"
        t3_rc=1
        bash "$qdir/reset.sh" 2>/dev/null || true
        sleep 3
        continue
      fi
    fi
  fi

  # Apply reference solution
  bash "$qdir/ref-solution.sh" > /dev/null 2>&1
  if (( $? != 0 )); then
    echo -e "${RED}FAIL${NC} (ref-solution failed)"
    t3_rc=1
    bash "$qdir/reset.sh" 2>/dev/null || true
    sleep 3
    continue
  fi

  # Grade with solution — expect PASS (score == max)
  pass_out=$(bash "$qdir/grade.sh" 2>/dev/null)
  pass_rc=$?
  score_line=$(echo "$pass_out" | grep "SCORE:" || true)

  if [[ -z "$score_line" ]]; then
    echo -e "${RED}FAIL${NC} (no SCORE line after ref-solution)"
    t3_rc=1
  else
    scored=$(echo "$score_line" | sed 's/.*SCORE: \([0-9]*\)\/\([0-9]*\).*/\1 \2/')
    got=$(echo "$scored" | cut -d' ' -f1)
    max=$(echo "$scored" | cut -d' ' -f2)
    if (( got == max )); then
      echo -e "${GREEN}PASS${NC} (fail: ${fail_traps} traps, pass: $got/$max)"
    else
      echo -e "${RED}FAIL${NC} (expected $max/$max, got $got/$max)"
      echo "        Output: $pass_out"
      t3_rc=1
    fi
  fi

  # Cleanup
  bash "$qdir/reset.sh" 2>/dev/null || true
  sleep 3
done

report "5-domain round-trip (FAIL without solution, PASS with ref-solution)" $t3_rc

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
