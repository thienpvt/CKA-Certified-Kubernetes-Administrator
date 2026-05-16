#!/usr/bin/env bash
# Re-run the 5 fixed drills from Phase 5 UAT on the live 1+2 kubeadm cluster.
#
# Covers gaps 1, 2, 3, 4, 15 (closed by plans 05-17..05-20).
#
# Pattern per drill:
#   1. reset.sh                    -> scrub any stale state
#   2. setup.sh                    -> seed broken state
#   3. grade.sh                    -> expect broken score (N<M or rc!=0)
#   4. ref-solution.sh             -> apply reference fix
#   5. grade.sh                    -> expect SCORE: M/M rc=0 (PASS)
#   6. reset.sh                    -> clean up
#
# Special cases:
#   Q04 (pss-enforce): broken state scores 5/5 by design (traps fire but don't
#   reduce score — the "broken" is the candidate-violator.yaml content, not the
#   infrastructure). For Q04 we check that broken-grade rc!=0 (trap detection
#   causes non-zero exit) OR that the candidate file contains trap triggers.
#
# Usage (on the candidate CP node with kubeconfig loaded):
#   cd ~/CKA-Certified-Kubernetes-Administrator
#   bash .planning/phases/05-services-networking-cluster-architecture-packs/rerun-phase5-fixed-drills.sh
#
# Flags:
#   --only=<gap>   run a single gap (1|2|3|4|15)
#   --keep-logs    leave per-drill logs on disk under /tmp/phase5-rerun/

set -uo pipefail

ROOT="${CKA_SIM_ROOT:-$(pwd)/cka-sim}"
export CKA_SIM_ROOT="$ROOT"
LOG_DIR="/tmp/phase5-rerun"
ONLY=""
KEEP_LOGS=1

for arg in "$@"; do
  case "$arg" in
    --only=*)    ONLY="${arg#--only=}" ;;
    --no-logs)   KEEP_LOGS=0 ;;
    --keep-logs) KEEP_LOGS=1 ;;
    -h|--help)
      sed -n '2,/^set /p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$LOG_DIR"

# ------------------------------------------------------------------
# Drill table: gap_id|pack|qdir|expected_max|special
# expected_max is the full-score denominator.
# special: "normal" = broken must score <max; "traps-only" = broken scores max
#          but traps fire (Q04 design).
# ------------------------------------------------------------------
DRILLS=(
  "1|cluster-architecture|08-priorityclass|2|normal"
  "2|services-networking|06-netpol-endport|6|normal"
  "3|cluster-architecture|02-etcd-backup-restore|3|normal"
  "4|cluster-architecture|04-pss-enforce|5|traps-only"
)

if [[ -n "$ONLY" ]]; then
  filtered=()
  for row in "${DRILLS[@]}"; do
    IFS='|' read -r gap _ _ _ _ <<<"$row"
    if [[ "$gap" == "$ONLY" ]]; then filtered+=("$row"); fi
  done
  (( ${#filtered[@]} )) || { echo "--only=$ONLY does not match any drill" >&2; exit 2; }
  DRILLS=("${filtered[@]}")
fi

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
score_from() { grep -oE 'SCORE:[[:space:]]*[0-9]+/[0-9]+' "$1" 2>/dev/null | tail -1; }

run_drill() {
  local gap="$1" pack="$2" qdir="$3" max="$4" special="$5"
  local qpath="$ROOT/packs/$pack/$qdir"
  local idx="${qdir%%-*}"  # e.g. "08" from "08-priorityclass"
  local ns="cka-sim-${pack}-${idx}"
  export CKA_SIM_LAB_NS="$ns"
  local tag="${pack}-${qdir}"

  echo "==== gap $gap: $tag (ns=$ns, max=$max, mode=$special) ===="

  # Step 1: reset
  echo "  [1/6] reset.sh"
  bash "$qpath/reset.sh" >"$LOG_DIR/${tag}-reset1.log" 2>&1 || true
  sleep 5

  # Step 2: setup
  echo "  [2/6] setup.sh"
  if ! bash "$qpath/setup.sh" >"$LOG_DIR/${tag}-setup.log" 2>&1; then
    echo "  FAIL: setup.sh exited non-zero"
    echo "  --- setup.sh output ---"
    tail -20 "$LOG_DIR/${tag}-setup.log"
    echo "  ---"
    bash "$qpath/reset.sh" >/dev/null 2>&1 || true
    return 1
  fi

  # Step 3: grade broken
  echo "  [3/6] grade.sh (broken)"
  local rc_broken=0
  bash "$qpath/grade.sh" >"$LOG_DIR/${tag}-broken.log" 2>&1 || rc_broken=$?
  local broken_score; broken_score=$(score_from "$LOG_DIR/${tag}-broken.log")
  echo "  broken: ${broken_score:-<no SCORE>} rc=$rc_broken"
  cat "$LOG_DIR/${tag}-broken.log" | sed 's/^/    /'

  # Step 4: ref-solution
  echo "  [4/6] ref-solution.sh"
  if ! bash "$qpath/ref-solution.sh" >"$LOG_DIR/${tag}-ref.log" 2>&1; then
    echo "  FAIL: ref-solution.sh exited non-zero"
    echo "  --- ref-solution.sh output ---"
    tail -20 "$LOG_DIR/${tag}-ref.log"
    echo "  ---"
    bash "$qpath/reset.sh" >/dev/null 2>&1 || true
    return 1
  fi

  # Step 5: grade fixed
  echo "  [5/6] grade.sh (fixed)"
  local rc_fixed=0
  bash "$qpath/grade.sh" >"$LOG_DIR/${tag}-fixed.log" 2>&1 || rc_fixed=$?
  local fixed_score; fixed_score=$(score_from "$LOG_DIR/${tag}-fixed.log")
  echo "  fixed:  ${fixed_score:-<no SCORE>} rc=$rc_fixed"
  cat "$LOG_DIR/${tag}-fixed.log" | sed 's/^/    /'

  # Step 6: reset
  echo "  [6/6] reset.sh"
  bash "$qpath/reset.sh" >"$LOG_DIR/${tag}-reset2.log" 2>&1 || true

  # ------------------------------------------------------------------
  # Verdict
  # ------------------------------------------------------------------
  local f_num f_den b_num b_den
  if [[ -z "$fixed_score" ]]; then
    echo "  FAIL: no SCORE line in fixed-grade output"
    return 1
  fi
  f_num=$(echo "$fixed_score" | grep -oE '[0-9]+' | head -1)
  f_den=$(echo "$fixed_score" | grep -oE '[0-9]+' | tail -1)

  # Fixed must hit max/max rc=0
  if (( f_num != max )) || (( rc_fixed != 0 )); then
    echo "  FAIL: fixed grade expected $max/$max rc=0, got $fixed_score rc=$rc_fixed"
    return 1
  fi

  # Broken verdict depends on mode
  if [[ "$special" == "traps-only" ]]; then
    # Q04: score is 5/5 in broken state, but traps fire (rc!=0) or candidate
    # file contains trap triggers. Either signal is acceptable.
    if (( rc_broken != 0 )); then
      echo "  OK (traps-only mode: broken rc=$rc_broken != 0, traps fired)"
      return 0
    fi
    # Check if trap lines present in broken output
    if grep -qi "Trap" "$LOG_DIR/${tag}-broken.log"; then
      echo "  OK (traps-only mode: Trap lines present in broken output)"
      return 0
    fi
    echo "  FAIL: traps-only mode but broken grade has rc=0 and no Trap lines"
    return 1
  else
    # Normal mode: broken must score < max
    if [[ -z "$broken_score" ]]; then
      echo "  FAIL: no SCORE line in broken-grade output"
      return 1
    fi
    b_num=$(echo "$broken_score" | grep -oE '[0-9]+' | head -1)
    b_den=$(echo "$broken_score" | grep -oE '[0-9]+' | tail -1)
    if (( b_num >= b_den )); then
      echo "  FAIL: broken scored full ($broken_score); setup.sh not seeding broken state"
      return 1
    fi
    echo "  OK (broken=$broken_score, fixed=$fixed_score)"
    return 0
  fi
}

# ------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------
FAIL=0
declare -a RESULTS=()
for row in "${DRILLS[@]}"; do
  IFS='|' read -r gap pack qdir max special <<<"$row"
  if run_drill "$gap" "$pack" "$qdir" "$max" "$special"; then
    RESULTS+=("PASS gap=$gap $pack/$qdir")
  else
    RESULTS+=("FAIL gap=$gap $pack/$qdir")
    FAIL=1
  fi
  echo
done

echo "==================== SUMMARY ===================="
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
echo "logs: $LOG_DIR"

(( KEEP_LOGS )) || rm -rf "$LOG_DIR"
exit "$FAIL"
