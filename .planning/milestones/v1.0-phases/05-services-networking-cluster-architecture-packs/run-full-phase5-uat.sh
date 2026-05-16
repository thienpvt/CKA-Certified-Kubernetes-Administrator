#!/usr/bin/env bash
# Full Phase 5 UAT: run all 14 questions (6 S&N + 8 CA) end-to-end.
#
# Pattern per drill:
#   reset -> setup -> grade(broken) -> ref-solution -> grade(fixed) -> reset
#
# Usage:
#   cd ~/CKA-Certified-Kubernetes-Administrator
#   bash .planning/phases/05-services-networking-cluster-architecture-packs/run-full-phase5-uat.sh
#
# Flags:
#   --only=<pack>:<n>   run a single question (e.g. --only=services-networking:3)
#   --skip-wait         skip the 5s post-reset sleep (faster but may race)

set -uo pipefail

ROOT="${CKA_SIM_ROOT:-$(pwd)/cka-sim}"
export CKA_SIM_ROOT="$ROOT"
LOG_DIR="/tmp/phase5-full-uat"
ONLY=""
WAIT=5

for arg in "$@"; do
  case "$arg" in
    --only=*)     ONLY="${arg#--only=}" ;;
    --skip-wait)  WAIT=0 ;;
    -h|--help)
      sed -n '2,/^set /p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$LOG_DIR"

# ------------------------------------------------------------------
# All Phase 5 questions
# pack|qdir|max|mode
#   mode: normal = broken must score <max
#         traps-only = broken scores max but traps fire (rc!=0)
# ------------------------------------------------------------------
QUESTIONS=(
  "services-networking|01-networkpolicy-egress|3|normal"
  "services-networking|02-service-core|3|normal"
  "services-networking|03-coredns-resolution|3|normal"
  "services-networking|04-ingress-path-host|5|normal"
  "services-networking|05-kube-proxy-mode|2|normal"
  "services-networking|06-netpol-endport|6|normal"
  "cluster-architecture|01-rbac-viewer|4|normal"
  "cluster-architecture|02-etcd-backup-restore|3|normal"
  "cluster-architecture|03-kubeadm-upgrade|5|normal"
  "cluster-architecture|04-pss-enforce|5|traps-only"
  "cluster-architecture|05-audit-policy|3|normal"
  "cluster-architecture|06-crd-basics|5|normal"
  "cluster-architecture|07-cri-dockerd-endpoint|2|normal"
  "cluster-architecture|08-priorityclass|2|normal"
)

if [[ -n "$ONLY" ]]; then
  IFS=':' read -r fpack fn <<<"$ONLY"
  filtered=()
  for row in "${QUESTIONS[@]}"; do
    IFS='|' read -r pack qdir max mode <<<"$row"
    idx="${qdir%%-*}"
    # Match by pack prefix and question number (with or without leading zero)
    if [[ "$pack" == *"$fpack"* ]] && [[ "$((10#$idx))" == "$((10#$fn))" ]]; then
      filtered+=("$row")
    fi
  done
  (( ${#filtered[@]} )) || { echo "--only=$ONLY does not match any question" >&2; exit 2; }
  QUESTIONS=("${filtered[@]}")
fi

# ------------------------------------------------------------------
score_from() { grep -oE 'SCORE:[[:space:]]*[0-9]+/[0-9]+' "$1" 2>/dev/null | tail -1; }

run_question() {
  local pack="$1" qdir="$2" max="$3" mode="$4"
  local qpath="$ROOT/packs/$pack/$qdir"
  local idx="${qdir%%-*}"
  local ns="cka-sim-${pack}-${idx}"
  export CKA_SIM_LAB_NS="$ns"
  local tag="${pack}-${qdir}"
  local qnum="$((10#$idx))"

  printf '\n==================== %s Q%02d  [%s]  ns=%s ====================\n' \
    "$pack" "$qnum" "$qdir" "$ns"

  # 1. Reset
  bash "$qpath/reset.sh" >"$LOG_DIR/${tag}-reset1.log" 2>&1 || true
  (( WAIT > 0 )) && sleep "$WAIT"

  # 2. Setup
  if ! bash "$qpath/setup.sh" >"$LOG_DIR/${tag}-setup.log" 2>&1; then
    echo "[$pack Q$qnum] FAIL setup.sh (see $LOG_DIR/${tag}-setup.log)"
    tail -5 "$LOG_DIR/${tag}-setup.log" | sed 's/^/  /'
    bash "$qpath/reset.sh" >/dev/null 2>&1 || true
    return 1
  fi

  # 3. Grade broken
  local rc_broken=0
  bash "$qpath/grade.sh" >"$LOG_DIR/${tag}-broken.log" 2>&1 || rc_broken=$?
  local broken_score; broken_score=$(score_from "$LOG_DIR/${tag}-broken.log")
  echo "[$pack Q$qnum] broken SCORE : ${broken_score:-<none>}"

  # 4. Ref-solution
  if ! bash "$qpath/ref-solution.sh" >"$LOG_DIR/${tag}-ref.log" 2>&1; then
    echo "[$pack Q$qnum] FAIL ref-solution.sh (see $LOG_DIR/${tag}-ref.log)"
    tail -5 "$LOG_DIR/${tag}-ref.log" | sed 's/^/  /'
    bash "$qpath/reset.sh" >/dev/null 2>&1 || true
    return 1
  fi

  # 5. Grade fixed
  local rc_fixed=0
  bash "$qpath/grade.sh" >"$LOG_DIR/${tag}-fixed.log" 2>&1 || rc_fixed=$?
  local fixed_score; fixed_score=$(score_from "$LOG_DIR/${tag}-fixed.log")
  echo "[$pack Q$qnum] pass   SCORE : ${fixed_score:-<none>}"

  # 6. Reset
  bash "$qpath/reset.sh" >"$LOG_DIR/${tag}-reset2.log" 2>&1 || true

  # ------------------------------------------------------------------
  # Verdict
  # ------------------------------------------------------------------
  if [[ -z "$fixed_score" ]]; then
    echo "[$pack Q$qnum] FAIL: no SCORE in fixed output"
    return 1
  fi
  local f_num; f_num=$(echo "$fixed_score" | grep -oE '[0-9]+' | head -1)

  # Fixed must hit max/max rc=0
  if (( f_num != max )) || (( rc_fixed != 0 )); then
    echo "[$pack Q$qnum] FAIL: fixed expected $max/$max rc=0, got $fixed_score rc=$rc_fixed"
    return 1
  fi

  # Broken verdict
  if [[ "$mode" == "traps-only" ]]; then
    if (( rc_broken != 0 )) || grep -qi "Trap" "$LOG_DIR/${tag}-broken.log"; then
      echo "[$pack Q$qnum] broken-grade-rc: grade-broken rc=$rc_broken"
      echo "[$pack Q$qnum] pass-grade-rc  : grade-pass rc=$rc_fixed"
      return 0
    fi
    echo "[$pack Q$qnum] FAIL: traps-only but no trap signal in broken grade"
    return 1
  else
    if [[ -z "$broken_score" ]]; then
      echo "[$pack Q$qnum] FAIL: no SCORE in broken output"
      return 1
    fi
    local b_num; b_num=$(echo "$broken_score" | grep -oE '[0-9]+' | head -1)
    local b_den; b_den=$(echo "$broken_score" | grep -oE '[0-9]+' | tail -1)
    if (( b_num >= b_den )); then
      echo "[$pack Q$qnum] FAIL: broken scored full ($broken_score)"
      return 1
    fi
    echo "[$pack Q$qnum] broken-grade-rc: grade-broken rc=$rc_broken"
    echo "[$pack Q$qnum] pass-grade-rc  : grade-pass rc=$rc_fixed"
    return 0
  fi
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
TOTAL=0
PASSED=0
FAILED=0
declare -a RESULTS=()

for row in "${QUESTIONS[@]}"; do
  IFS='|' read -r pack qdir max mode <<<"$row"
  TOTAL=$(( TOTAL + 1 ))
  if run_question "$pack" "$qdir" "$max" "$mode"; then
    PASSED=$(( PASSED + 1 ))
    RESULTS+=("PASS $pack/${qdir}")
  else
    FAILED=$(( FAILED + 1 ))
    RESULTS+=("FAIL $pack/${qdir}")
  fi
done

echo
echo "==================== FINAL SUMMARY ===================="
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
echo "  Total: $TOTAL | Passed: $PASSED | Failed: $FAILED"
echo "  Logs: $LOG_DIR"
echo

exit $(( FAILED > 0 ? 1 : 0 ))
