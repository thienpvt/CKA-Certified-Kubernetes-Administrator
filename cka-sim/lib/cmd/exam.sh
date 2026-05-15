#!/bin/bash
# cka-sim exam — take a timed mock exam (Phase 7).
# Replaces the Phase 1 stub.

set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../preflight.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/preflight.sh"
# shellcheck source=../exam-state.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/exam-state.sh"
# shellcheck source=../exam-blueprint.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/exam-blueprint.sh"
# shellcheck source=../exam-report.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/exam-report.sh"
# shellcheck source=../exam-timer.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/exam-timer.sh"

declare -g CKA_SIM_EXAM_CUR_IDX=0
declare -ag CKA_SIM_EXAM_SETUP_IDXS=()
declare -ag CKA_SIM_EXAM_QDIRS=()
declare -g CKA_SIM_EXAM_QUESTION_COUNT=0
declare -g CKA_SIM_EXAM_ENDED=0
declare -g CKA_SIM_LAB_NS=""
declare -g CKA_SIM_EXAM_STTY_SAVED=""
declare -g CKA_SIM_EXAM_IN_SIGHANDLER=0
declare -g CKA_SIM_EXAM_SIGNAL_FIRED=0
declare -g CKA_SIM_EXAM_RESUME_PENDING=0
# Active input prompt — signal handlers re-print this because bash restarts an
# interrupted `read` in-place (it does NOT return on a trapped signal), so the
# read loop never gets a chance to re-print the prompt itself.
declare -g CKA_SIM_EXAM_PROMPT='> '

# Exports CKA_SIM_LAB_NS for the question at $idx so its setup/grade/reset
# scripts see the same per-question lab namespace the drill runner gives them.
# Convention matches drill.sh: cka-sim-<pack>-<NN> (NN = slug's leading number).
cka_sim::exam::export_lab_ns() {
  local idx="$1"
  local pack slug num
  pack=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$idx].pack")
  slug=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$idx].slug")
  num="${slug%%-*}"
  CKA_SIM_LAB_NS="cka-sim-${pack}-${num}"
  export CKA_SIM_LAB_NS
}

cka_sim::exam::usage() {
  cat >&2 <<'EOF'
usage: cka-sim exam <blueprint>
       cka-sim exam --resume <ts>

  <blueprint>   Name of an exam blueprint under exams/ (e.g., blueprint-alpha)
  --resume <ts> Resume an interrupted session by timestamp

Controls during exam:
  [Enter/n] = advance to next question
  [f]       = flag current question for review
  [s]       = skip current question
  [p]       = go back to previous question
  [t]       = show time remaining (without advancing)
  [q]       = end exam and submit for grading

Signals:
  Ctrl-C    = flag current question (does NOT kill the exam)
  Ctrl-Z    = pause (state saved; resume with fg)
EOF
}

cka_sim::exam::format_remaining() {
  local now remaining
  now=$(cka_sim::state::now)
  remaining=$(( CKA_SIM_EXAM_DEADLINE_TS - now ))
  (( remaining < 0 )) && remaining=0
  printf '%02d:%02d:%02d' $((remaining/3600)) $(((remaining%3600)/60)) $((remaining%60))
}

cka_sim::exam::on_int() {
  CKA_SIM_EXAM_SIGNAL_FIRED=1
  cka_sim::state::set_question_status "$CKA_SIM_EXAM_CUR_IDX" "flagged"
  cka_sim::state::save
  printf '\n\033[33m✓ Q%d flagged. Continuing…\033[0m\n' \
    "$(( CKA_SIM_EXAM_CUR_IDX + 1 ))" >&2
  # `read` restarts in-place after this trap returns — re-print the prompt so
  # the user sees the exam is still waiting for input.
  printf '%s' "$CKA_SIM_EXAM_PROMPT" >&2
  return 0
}

cka_sim::exam::on_tstp() {
  CKA_SIM_EXAM_SIGNAL_FIRED=1
  CKA_SIM_EXAM_RESUME_PENDING=1
  # Pre-stop: record pause time. DO NOT touch stty here — bash will reclaim
  # the terminal once we stop and change its modes, so any restore now is
  # wasted. Restore stty AFTER resume instead.
  cka_sim::state::set_pause
  # Default-stop: restore default disposition, self-deliver TSTP.
  trap - TSTP
  kill -TSTP $$
  # === resumes here after fg ===
  trap 'cka_sim::exam::on_tstp' TSTP
  trap 'cka_sim::exam::on_int'  INT
  # Restore terminal modes — bash flips icanon/echo while we're stopped, and
  # repeated Ctrl-Z/fg cycles can compound the drift until `read` is waiting
  # forever for a line terminator the TTY no longer delivers. Belt-and-
  # suspenders: stty sane first (known-good baseline), then re-apply our
  # captured state, then force the absolute minimum we depend on.
  stty sane 2>/dev/null || true
  stty "$CKA_SIM_EXAM_STTY_SAVED" 2>/dev/null || true
  stty echo icanon isig 2>/dev/null || true
  cka_sim::state::add_pause_delta
  # NOTE: do NOT call present_question or state::save (heavy jq) from inside
  # this trap. set -e + pipefail inside a trap can corrupt the interrupted
  # read's return path and make subsequent setup output disappear. The main
  # loop checks CKA_SIM_EXAM_RESUME_PENDING and does redisplay there.
}

cka_sim::exam::on_cont() {
  return 0
}

cka_sim::exam::on_exit() {
  local rc=$?
  # Kill timer child explicitly
  kill "${CKA_SIM_TIMER_PID:-}" 2>/dev/null || true
  wait "${CKA_SIM_TIMER_PID:-}" 2>/dev/null || true
  CKA_SIM_TIMER_PID=""
  rm -f "${CKA_SIM_TIMER_GATE:-}" 2>/dev/null || true
  # Restore terminal echo/mode in case setup_question left it off mid-error.
  [[ -n "${CKA_SIM_EXAM_STTY_SAVED:-}" ]] && stty "$CKA_SIM_EXAM_STTY_SAVED" 2>/dev/null || true
  cka_sim::state::save 2>/dev/null || true
  local i qdir
  for i in "${CKA_SIM_EXAM_SETUP_IDXS[@]:-}"; do
    [[ -z "$i" ]] && continue
    qdir="${CKA_SIM_EXAM_QDIRS[$i]:-}"
    cka_sim::exam::export_lab_ns "$i"
    [[ -n "$qdir" && -x "$qdir/reset.sh" ]] && bash "$qdir/reset.sh" 2>/dev/null || true
  done
  exit "$rc"
}

cka_sim::exam::present_question() {
  local idx="$1"
  local qdir="${CKA_SIM_EXAM_QDIRS[$idx]}"
  local qid domain est status
  qid=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$idx].id // \"q$((idx+1))\"")
  domain=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$idx].domain // \"—\"")
  est=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$idx].estimatedMinutes // \"?\"" 2>/dev/null || echo "?")
  status=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$idx].status // \"pending\"")

  local marker=""
  [[ "$status" == "flagged" ]] && marker=" 🚩"
  [[ "$status" == "skipped" ]] && marker=" ↷"

  printf '\n'
  printf '%s[Question %d/%d — %s — ~%sm]   [⏱  %s remaining]%s%s\n' \
    "$BOLD" "$((idx + 1))" "$CKA_SIM_EXAM_QUESTION_COUNT" "$domain" "$est" \
    "$(cka_sim::exam::format_remaining)" "$NC" "$marker"
  printf '%s\n' "─────────────────────────────────────────"

  if [[ -r "$qdir/question.md" ]]; then
    cat "$qdir/question.md"
  fi

  printf '\n%s[Enter/n]=next  [f]=flag  [s]=skip  [p]=prev  [t]=time  [q]=end exam%s\n' "$YELLOW" "$NC"
}

cka_sim::exam::handle_action() {
  local action="$1"

  case "$action" in
    ""|n)
      CKA_SIM_EXAM_CUR_IDX=$(( CKA_SIM_EXAM_CUR_IDX + 1 ))
      ;;
    f)
      cka_sim::state::set_question_status "$CKA_SIM_EXAM_CUR_IDX" "flagged"
      CKA_SIM_EXAM_CUR_IDX=$(( CKA_SIM_EXAM_CUR_IDX + 1 ))
      ;;
    s)
      cka_sim::state::set_question_status "$CKA_SIM_EXAM_CUR_IDX" "skipped"
      CKA_SIM_EXAM_CUR_IDX=$(( CKA_SIM_EXAM_CUR_IDX + 1 ))
      ;;
    p)
      (( CKA_SIM_EXAM_CUR_IDX > 0 )) && CKA_SIM_EXAM_CUR_IDX=$(( CKA_SIM_EXAM_CUR_IDX - 1 ))
      ;;
    q)
      CKA_SIM_EXAM_ENDED=1
      ;;
    *)
      warn "Unknown action: '$action'. Use Enter/n/f/s/p/q."
      ;;
  esac

  cka_sim::state::save
}

cka_sim::exam::setup_question() {
  local idx="$1"
  local qdir="${CKA_SIM_EXAM_QDIRS[$idx]}"

  local already_setup=0
  local s
  for s in "${CKA_SIM_EXAM_SETUP_IDXS[@]:-}"; do
    [[ "$s" == "$idx" ]] && already_setup=1 && break
  done

  if (( ! already_setup )); then
    info "Setting up Q$((idx + 1))... (don't type until '>' returns)"
    cka_sim::exam::export_lab_ns "$idx"
    # Defer TSTP during setup — kubectl children in the foreground process group
    # get confused by mid-operation stops. Queue the stop for after setup finishes.
    trap '' TSTP
    # Silence TTY echo + flush input so stray keystrokes during setup don't
    # smear across kubectl output OR auto-consume the next read prompt.
    stty -echo 2>/dev/null || true
    bash "$qdir/reset.sh" </dev/null 2>/dev/null || true
    local setup_rc=0
    bash "$qdir/setup.sh" </dev/null || setup_rc=$?
    local _drain=""
    while IFS= read -r -t 0.05 -N 1024 _drain 2>/dev/null; do :; done
    stty echo 2>/dev/null || true
    trap 'cka_sim::exam::on_tstp' TSTP
    if (( setup_rc != 0 )); then
      warn "Q$((idx + 1)) setup interrupted or failed (rc=$setup_rc) — question flagged"
      cka_sim::state::set_question_status "$idx" "flagged"
      return 1
    fi
    CKA_SIM_EXAM_SETUP_IDXS+=("$idx")
  fi
}

cka_sim::exam::check_time_remaining() {
  local now
  now=$(cka_sim::state::now)
  if (( now >= CKA_SIM_EXAM_DEADLINE_TS )); then
    printf '\n%s⏱ Time is up!%s\n' "$RED" "$NC" >&2
    CKA_SIM_EXAM_ENDED=1
    return 1
  fi
  return 0
}

cka_sim::exam::question_loop() {
  local start_idx="${1:-0}"
  CKA_SIM_EXAM_CUR_IDX="$start_idx"

  trap 'cka_sim::exam::on_int' INT
  trap 'cka_sim::exam::on_tstp' TSTP
  trap 'cka_sim::exam::on_cont' CONT
  trap 'cka_sim::exam::on_exit' EXIT

  while (( CKA_SIM_EXAM_CUR_IDX < CKA_SIM_EXAM_QUESTION_COUNT && CKA_SIM_EXAM_ENDED == 0 )); do
    cka_sim::exam::check_time_remaining || break

    local setup_ok=0
    cka_sim::exam::setup_question "$CKA_SIM_EXAM_CUR_IDX" && setup_ok=1 || true
    if (( ! setup_ok )); then
      # Setup interrupted/failed — question already flagged; advance to next
      CKA_SIM_EXAM_CUR_IDX=$(( CKA_SIM_EXAM_CUR_IDX + 1 ))
      continue
    fi

    cka_sim::exam::present_question "$CKA_SIM_EXAM_CUR_IDX"

    CKA_SIM_EXAM_QUESTIONS_JSON=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" \
      | jq --argjson i "$CKA_SIM_EXAM_CUR_IDX" \
           --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
           'if .[$i].started_at == null then .[$i].started_at = $ts else . end')
    cka_sim::state::save

    local action=""
    CKA_SIM_EXAM_PROMPT='> '
    while true; do
      # If we just came back from a Ctrl-Z/fg cycle, redisplay context here
      # (NOT inside the trap, where set -e + jq can break the read path).
      if (( CKA_SIM_EXAM_RESUME_PENDING == 1 )); then
        CKA_SIM_EXAM_RESUME_PENDING=0
        cka_sim::state::save
        # Drain any chars the candidate typed between Ctrl-Z and fg so they
        # don't auto-consume the next read.
        local _drain=""
        while IFS= read -r -t 0.05 -N 1024 _drain 2>/dev/null; do :; done
        printf '\n\033[32m✓ Resumed. (⏱  %s remaining)\033[0m\n' \
          "$(cka_sim::exam::format_remaining)" >&2
        cka_sim::exam::present_question "$CKA_SIM_EXAM_CUR_IDX"
      fi
      printf '> '
      local rc=0
      read -r action || rc=$?
      if (( rc != 0 )); then
        if (( rc > 128 )); then
          # Signal-interrupted read — top of loop will re-prompt (and
          # redisplay if RESUME_PENDING was just set).
          continue
        else
          CKA_SIM_EXAM_ENDED=1
          break 2
        fi
      fi
      # `t` queries time without leaving the prompt
      if [[ "$action" == "t" ]]; then
        printf '⏱  %s remaining\n' "$(cka_sim::exam::format_remaining)"
        continue
      fi
      break
    done

    cka_sim::exam::handle_action "$action"
  done

  if (( CKA_SIM_EXAM_CUR_IDX >= CKA_SIM_EXAM_QUESTION_COUNT )); then
    CKA_SIM_EXAM_ENDED=1
  fi

  cka_sim::exam::confirm_submit
}

cka_sim::exam::confirm_submit() {
  local flagged=0 skipped=0 answered=0 pending=0
  local i status
  for (( i=0; i<CKA_SIM_EXAM_QUESTION_COUNT; i++ )); do
    status=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$i].status // \"pending\"")
    case "$status" in
      flagged) flagged=$(( flagged + 1 )) ;;
      skipped) skipped=$(( skipped + 1 )) ;;
      passed|failed|answered) answered=$(( answered + 1 )) ;;
      *) pending=$(( pending + 1 )) ;;
    esac
  done

  printf '\n%s━━━ Exam Summary ━━━%s\n' "$BOLD" "$NC"
  printf 'Flagged: %d  Skipped: %d  Pending: %d\n' "$flagged" "$skipped" "$pending"

  local confirm=""
  CKA_SIM_EXAM_PROMPT='Submit for grading? [y/n] '
  while true; do
    printf '\nSubmit for grading? [y/n] '
    local rc=0
    read -r confirm || rc=$?
    if (( rc == 0 )); then
      break
    elif (( rc > 128 )); then
      # Trap-interrupted — re-prompt
      continue
    else
      # Genuine EOF — default to submit
      confirm="y"
      break
    fi
  done

  if [[ "$confirm" != "y" && "$confirm" != "Y" && "$confirm" != "" ]]; then
    CKA_SIM_EXAM_ENDED=0
    cka_sim::exam::question_loop "$CKA_SIM_EXAM_CUR_IDX"
    return
  fi

  cka_sim::exam::batch_grade
}

cka_sim::exam::batch_grade() {
  # Disable Ctrl-C (which would otherwise flag a stale CUR_IDX as "flagged")
  # and Ctrl-Z (suspending in the middle of grading is not sensible) for the
  # duration of grading.
  trap '' INT TSTP
  cka_sim::timer::stop
  printf '\n%s━━━ Grading ━━━%s\n' "$BOLD" "$NC" >&2

  local i qdir status tmp rc capture
  for (( i=0; i<CKA_SIM_EXAM_QUESTION_COUNT; i++ )); do
    qdir="${CKA_SIM_EXAM_QDIRS[$i]}"
    status=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$i].status // \"pending\"")

    if [[ "$status" == "skipped" ]]; then
      local max_score=8
      cka_sim::state::record_grade "$i" 1 "SCORE: 0/$max_score"
      info "Q$((i+1)): skipped (0/$max_score)"
      continue
    fi

    info "Grading Q$((i+1))..."
    cka_sim::exam::export_lab_ns "$i"
    tmp=$(mktemp -t "cka-sim-grade.XXXXXX")
    rc=0
    bash "$qdir/grade.sh" </dev/null > "$tmp" 2>&1 || rc=$?
    capture=$(cat "$tmp")
    rm -f "$tmp"

    cka_sim::state::record_grade "$i" "$rc" "$capture"
    cka_sim::state::transcript_append "$i" "$capture"

    local score_line
    score_line=$(printf '%s' "$capture" | grep -oE 'SCORE: [0-9]+/[0-9]+' | head -1 || true)
    if (( rc == 0 )); then
      ok "Q$((i+1)): PASS ${score_line:-}"
    else
      err "Q$((i+1)): FAIL ${score_line:-}"
    fi
  done

  cka_sim::state::save

  local report_path
  report_path="$(cka_sim::state::report_path "$CKA_SIM_EXAM_TS")"
  local session_path
  session_path="$(cka_sim::state::session_path "$CKA_SIM_EXAM_TS")"

  cka_sim::report::render "$session_path" "$report_path"
  CKA_SIM_EXAM_FINAL_REPORT="$report_path"
  cka_sim::state::save

  printf '\n%s━━━ Results ━━━%s\n' "$BOLD" "$NC"
  cat "$report_path"
  printf '\n'
  info "Report saved to: $report_path"
  info "Session data: $session_path"
}

cka_sim::exam::build_questions_json() {
  local questions_json="["
  local i pack slug domain est
  for (( i=0; i<${#CKA_SIM_BLUEPRINT_PACKS[@]}; i++ )); do
    pack="${CKA_SIM_BLUEPRINT_PACKS[$i]}"
    slug="${CKA_SIM_BLUEPRINT_SLUGS[$i]}"
    est="${CKA_SIM_BLUEPRINT_MINUTES[$i]}"

    local qdir
    qdir=$(cka_sim::blueprint::resolve_question "$pack" "$slug")
    CKA_SIM_EXAM_QDIRS+=("$qdir")

    domain=$(grep -oP '^domain: \K.*' "$qdir/metadata.yaml" 2>/dev/null || echo "$pack")
    domain="${domain//\"/}"

    (( i > 0 )) && questions_json+=","
    questions_json+=$(printf '{"id":"%s-%s","domain":"%s","pack":"%s","slug":"%s","idx":%d,"status":"pending","score":null,"max_score":null,"traps":[],"grade_raw":"","started_at":null,"completed_at":null,"estimatedMinutes":%d}' \
      "$pack" "$slug" "$domain" "$pack" "$slug" "$i" "${est:-7}")
  done
  questions_json+="]"
  CKA_SIM_EXAM_QUESTIONS_JSON_BUILT="$questions_json"
}

cka_sim::exam::start_new() {
  local blueprint_name="${1:?start_new: blueprint name required}"
  local manifest_dir="$CKA_SIM_ROOT/../exams/$blueprint_name"
  local manifest="$manifest_dir/manifest.yaml"

  if [[ ! -r "$manifest" ]]; then
    manifest_dir="$(cd "$CKA_SIM_ROOT/.." && pwd)/exams/$blueprint_name"
    manifest="$manifest_dir/manifest.yaml"
  fi
  [[ -r "$manifest" ]] || die "Blueprint not found: $manifest"

  cka_sim::preflight::check_kubeconfig >/dev/null \
    || die "no readable kubeconfig (run 'cka-sim doctor')"
  command -v jq >/dev/null 2>&1 \
    || die "jq not found (required for exam mode)"

  info "Loading blueprint: $blueprint_name"
  cka_sim::blueprint::load "$manifest"

  CKA_SIM_EXAM_QUESTION_COUNT=${#CKA_SIM_BLUEPRINT_PACKS[@]}
  info "Questions: $CKA_SIM_EXAM_QUESTION_COUNT"
  info "Duration: ${CKA_SIM_BLUEPRINT_META[durationMinutes]:-120} minutes"

  local questions_json
  cka_sim::exam::build_questions_json
  questions_json="$CKA_SIM_EXAM_QUESTIONS_JSON_BUILT"

  local duration="${CKA_SIM_BLUEPRINT_META[durationMinutes]:-120}"
  cka_sim::state::init "$blueprint_name" "$manifest" "$questions_json" "$duration"

  info "Session: $CKA_SIM_EXAM_TS"
  info "Starting exam..."
  printf '\n'

  CKA_SIM_EXAM_STTY_SAVED=$(stty -g 2>/dev/null || true)
  cka_sim::exam::question_loop 0
}

cka_sim::exam::resume() {
  local ts="${1:?resume: timestamp required}"

  cka_sim::state::load "$ts"

  CKA_SIM_EXAM_QUESTION_COUNT=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq 'length')

  CKA_SIM_EXAM_QDIRS=()
  local i pack slug
  for (( i=0; i<CKA_SIM_EXAM_QUESTION_COUNT; i++ )); do
    pack=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$i].pack")
    slug=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$i].slug")
    local qdir
    qdir=$(cka_sim::blueprint::resolve_question "$pack" "$slug")
    CKA_SIM_EXAM_QDIRS+=("$qdir")
  done

  local now
  now=$(cka_sim::state::now)
  if (( now >= CKA_SIM_EXAM_DEADLINE_TS )); then
    warn "Exam expired — grading completed questions"
    cka_sim::exam::batch_grade
    return
  fi

  local remaining=$(( CKA_SIM_EXAM_DEADLINE_TS - now ))
  local rm=$(( remaining / 60 ))
  info "Resuming session $ts ($rm minutes remaining)"

  cka_sim::exam::setup_question "$CKA_SIM_EXAM_CUR_IDX"

  CKA_SIM_EXAM_STTY_SAVED=$(stty -g 2>/dev/null || true)
  cka_sim::exam::question_loop "$CKA_SIM_EXAM_CUR_IDX"
}

cka_sim::exam::main() {
  case "${1:-}" in
    -h|--help|"")
      cka_sim::exam::usage
      exit 0
      ;;
    --resume)
      [[ -n "${2:-}" ]] || die "usage: cka-sim exam --resume <ts>"
      cka_sim::exam::resume "$2"
      ;;
    *)
      cka_sim::exam::start_new "$1"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cka_sim::exam::main "$@"
fi
