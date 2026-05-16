#!/usr/bin/env bash
# Phase 07.1 D-25 UAT: round-trip all 17 blueprint-alpha questions.
#
# Pattern per question:
#   reset -> setup -> grade(empty -> expect 0/max) -> ref-solution -> grade(ref -> expect max/max) -> reset
#
# Usage:
#   cd ~/CKA-Certified-Kubernetes-Administrator
#   bash .planning/phases/07.1-grading-honesty-rebuild-distinguish-setup-state-from-candida/run-blueprint-alpha-ref-uat.sh
#
# Flags:
#   --only=<pack>:<n>   run a single question (e.g. --only=storage:1)
#   --skip-wait         skip the 5s post-reset sleep
#   --skip-empty        skip the empty-submission check (only verify ref-solution)

set -uo pipefail

ROOT="${CKA_SIM_ROOT:-$(pwd)/cka-sim}"
export CKA_SIM_ROOT="$ROOT"
LOG_DIR="/tmp/phase071-blueprint-alpha-uat"
ONLY=""
WAIT=5
SKIP_EMPTY=0

for arg in "$@"; do
  case "$arg" in
    --only=*)     ONLY="${arg#--only=}" ;;
    --skip-wait)  WAIT=0 ;;
    --skip-empty) SKIP_EMPTY=1 ;;
    -h|--help)
      sed -n '2,/^set /p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$LOG_DIR"

# ------------------------------------------------------------------
# blueprint-alpha questions (17 total) — order matches exams/blueprint-alpha/manifest.yaml
# Format: pack|qdir|max_score
# max_score = expected ref-solution score after Phase 07.1 honest scoring
# ------------------------------------------------------------------
QUESTIONS=(
  "storage|01-pvc-binding|1"
  "troubleshooting|01-deploy-svc-mismatch|1"
  "workloads-scheduling|02-rolling-update-rollback|1"
  "services-networking|02-service-core|1"
  "cluster-architecture|06-crd-basics|5"
  "troubleshooting|02-netpol-dns-egress|3"
  "workloads-scheduling|05-daemonset|2"
  "services-networking|06-netpol-endport|6"
  "cluster-architecture|04-pss-enforce|1"
  "troubleshooting|04-debug-node|1"
  "storage|02-storageclass-dynamic|1"
  "cluster-architecture|07-cri-dockerd-endpoint|1"
  "workloads-scheduling|01-deployment-requests|4"
  "troubleshooting|03-coredns-resolution|4"
  "services-networking|05-kube-proxy-mode|3"
  "cluster-architecture|08-priorityclass|2"
  "troubleshooting|05-static-pod-manifest|3"
)

if [[ -n "$ONLY" ]]; then
  IFS=':' read -r fpack fn <<<"$ONLY"
  filtered=()
  for row in "${QUESTIONS[@]}"; do
    IFS='|' read -r pack qdir max <<<"$row"
    idx="${qdir%%-*}"
    if [[ "$pack" == *"$fpack"* ]] && [[ "$((10#$idx))" == "$((10#$fn))" ]]; then
      filtered+=("$row")
    fi
  done
  (( ${#filtered[@]} )) || { echo "--only=$ONLY does not match any question" >&2; exit 2; }
  QUESTIONS=("${filtered[@]}")
fi

# ------------------------------------------------------------------
score_from() { grep -oE 'SCORE:[[:space:]]*[0-9]+/[0-9]+' "$1" 2>/dev/null | tail -1; }
score_num()  { echo "$1" | grep -oE '[0-9]+' | head -1; }
score_den()  { echo "$1" | grep -oE '[0-9]+' | tail -1; }

run_question() {
  local pack="$1" qdir="$2" max="$3"
  local qpath="$ROOT/packs/$pack/$qdir"
  local slug="$qdir"
  local idx="${qdir%%-*}"
  local ns="cka-sim-${pack}-${idx}"
  export CKA_SIM_LAB_NS="$ns"
  export CKA_SIM_QUESTION_ID="$slug"
  export CKA_SIM_BASELINE_PATH="/tmp/cka-sim/${slug}/baseline.json"
  local tag="${pack}-${qdir}"

  printf '\n==================== %s/%s  ns=%s ====================\n' "$pack" "$qdir" "$ns"

  # 1. Reset (clear stale state)
  bash "$qpath/reset.sh" >"$LOG_DIR/${tag}-reset1.log" 2>&1 || true
  (( WAIT > 0 )) && sleep "$WAIT"

  # 2. Setup (creates lab namespace + seeded state)
  if ! bash "$qpath/setup.sh" >"$LOG_DIR/${tag}-setup.log" 2>&1; then
    echo "[$tag] FAIL setup.sh (see $LOG_DIR/${tag}-setup.log)"
    tail -5 "$LOG_DIR/${tag}-setup.log" | sed 's/^/  /'
    bash "$qpath/reset.sh" >/dev/null 2>&1 || true
    return 1
  fi

  # 2.5 Capture baseline (mirrors what exam.sh does between setup and prompt)
  source "$ROOT/lib/baseline.sh"
  if ! cka_sim::baseline::capture "$ns" >"$LOG_DIR/${tag}-baseline.log" 2>&1; then
    echo "[$tag] FAIL baseline capture (see $LOG_DIR/${tag}-baseline.log)"
    bash "$qpath/reset.sh" >/dev/null 2>&1 || true
    return 1
  fi

  # 3. Grade empty (should score 0/max)
  if (( SKIP_EMPTY == 0 )); then
    local empty_score
    bash "$qpath/grade.sh" >"$LOG_DIR/${tag}-empty.log" 2>&1 || true
    empty_score=$(score_from "$LOG_DIR/${tag}-empty.log")
    local e_num; e_num=$(score_num "$empty_score")
    if [[ -z "$empty_score" ]] || (( e_num != 0 )); then
      echo "[$tag] FAIL empty: expected 0/$max, got ${empty_score:-<none>}"
      bash "$qpath/reset.sh" >/dev/null 2>&1 || true
      return 1
    fi
    echo "[$tag] empty SCORE: ${empty_score} ✓"
  fi

  # 4. Apply ref-solution
  if ! bash "$qpath/ref-solution.sh" >"$LOG_DIR/${tag}-ref.log" 2>&1; then
    echo "[$tag] FAIL ref-solution.sh (see $LOG_DIR/${tag}-ref.log)"
    tail -10 "$LOG_DIR/${tag}-ref.log" | sed 's/^/  /'
    bash "$qpath/reset.sh" >/dev/null 2>&1 || true
    return 1
  fi

  # 5. Grade ref-solution (should score max/max)
  local rc_ref=0 ref_score
  bash "$qpath/grade.sh" >"$LOG_DIR/${tag}-graded.log" 2>&1 || rc_ref=$?
  ref_score=$(score_from "$LOG_DIR/${tag}-graded.log")
  echo "[$tag] ref-soln SCORE: ${ref_score:-<none>} rc=$rc_ref"

  # 6. Reset
  bash "$qpath/reset.sh" >"$LOG_DIR/${tag}-reset2.log" 2>&1 || true

  # 7. Verdict
  if [[ -z "$ref_score" ]]; then
    echo "[$tag] FAIL: no SCORE in ref-solution grade output"
    return 1
  fi
  local r_num; r_num=$(score_num "$ref_score")
  local r_den; r_den=$(score_den "$ref_score")
  if (( r_num != r_den )); then
    echo "[$tag] FAIL: ref-solution scored $ref_score (expected $r_den/$r_den)"
    tail -15 "$LOG_DIR/${tag}-graded.log" | sed 's/^/  /'
    return 1
  fi
  if (( r_den != max )); then
    echo "[$tag] WARN: max score drifted (expected $max, got $r_den) — update QUESTIONS table"
  fi
  echo "[$tag] PASS"
  return 0
}

# ------------------------------------------------------------------
TOTAL=0; PASSED=0; FAILED=0
declare -a RESULTS=()

for row in "${QUESTIONS[@]}"; do
  IFS='|' read -r pack qdir max <<<"$row"
  TOTAL=$(( TOTAL + 1 ))
  if run_question "$pack" "$qdir" "$max"; then
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
