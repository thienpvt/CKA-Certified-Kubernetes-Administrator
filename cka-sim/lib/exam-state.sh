#!/bin/bash
# cka-sim/lib/exam-state.sh — JSON session state read/write with atomic save.
# Sourced by lib/cmd/exam.sh and lib/cmd/score.sh.

set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

declare -g CKA_SIM_EXAM_TS=""
declare -g CKA_SIM_EXAM_BLUEPRINT_ID=""
declare -g CKA_SIM_EXAM_BLUEPRINT_PATH=""
declare -g CKA_SIM_EXAM_DEADLINE_TS=0
declare -g CKA_SIM_EXAM_PAUSED_AT=0
declare -g CKA_SIM_EXAM_PAUSED_SECONDS=0
declare -g CKA_SIM_EXAM_CUR_IDX=0
declare -g CKA_SIM_EXAM_QUESTIONS_JSON="[]"
declare -g CKA_SIM_EXAM_FINAL_REPORT=""
declare -g CKA_SIM_EXAM_STARTED_AT=""

cka_sim::state::now() {
  printf '%d' "${CKA_SIM_NOW_OVERRIDE:-$(date +%s)}"
}

cka_sim::state::session_dir() {
  printf '%s' "$HOME/.cka-sim/sessions"
}

cka_sim::state::session_path() {
  local ts="${1:?session_path: ts required}"
  printf '%s/%s.json' "$(cka_sim::state::session_dir)" "$ts"
}

cka_sim::state::log_path() {
  local ts="${1:?log_path: ts required}"
  printf '%s/%s.log' "$(cka_sim::state::session_dir)" "$ts"
}

cka_sim::state::report_path() {
  local ts="${1:?report_path: ts required}"
  printf '%s/%s.md' "$(cka_sim::state::session_dir)" "$ts"
}

cka_sim::state::init() {
  local blueprint_id="${1:?init: blueprint_id required}"
  local blueprint_path="${2:?init: blueprint_path required}"
  local questions_json="${3:?init: questions_json required}"
  local duration_minutes="${4:?init: duration_minutes required}"

  local session_dir
  session_dir="$(cka_sim::state::session_dir)"
  mkdir -p "$session_dir"
  chmod 700 "$session_dir" 2>/dev/null || true

  CKA_SIM_EXAM_TS=$(date -u +%Y%m%dT%H%M%SZ)
  CKA_SIM_EXAM_BLUEPRINT_ID="$blueprint_id"
  CKA_SIM_EXAM_BLUEPRINT_PATH="$blueprint_path"
  CKA_SIM_EXAM_STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  CKA_SIM_EXAM_DEADLINE_TS=$(( $(cka_sim::state::now) + duration_minutes * 60 ))
  CKA_SIM_EXAM_PAUSED_AT=0
  CKA_SIM_EXAM_PAUSED_SECONDS=0
  CKA_SIM_EXAM_CUR_IDX=0
  CKA_SIM_EXAM_QUESTIONS_JSON="$questions_json"
  CKA_SIM_EXAM_FINAL_REPORT=""

  cka_sim::state::save
}

cka_sim::state::load() {
  local ts="${1:?load: ts required}"
  local json_path
  json_path="$(cka_sim::state::session_path "$ts")"
  [[ -r "$json_path" ]] || die "session not found: $json_path"

  local version
  version=$(jq -r '.version' "$json_path")
  [[ "$version" == "1" ]] || die "unsupported session version: $version (expected 1)"

  CKA_SIM_EXAM_TS="$ts"
  CKA_SIM_EXAM_BLUEPRINT_ID=$(jq -r '.blueprint.id' "$json_path")
  CKA_SIM_EXAM_BLUEPRINT_PATH=$(jq -r '.blueprint.path' "$json_path")
  CKA_SIM_EXAM_STARTED_AT=$(jq -r '.started_at' "$json_path")
  CKA_SIM_EXAM_DEADLINE_TS=$(jq -r '.deadline_ts' "$json_path")
  CKA_SIM_EXAM_PAUSED_AT=$(jq -r '.paused_at // 0' "$json_path")
  CKA_SIM_EXAM_PAUSED_SECONDS=$(jq -r '.paused_seconds' "$json_path")
  CKA_SIM_EXAM_CUR_IDX=$(jq -r '.current_question_idx' "$json_path")
  CKA_SIM_EXAM_QUESTIONS_JSON=$(jq -c '.questions' "$json_path")
  CKA_SIM_EXAM_FINAL_REPORT=$(jq -r '.final_report_path // ""' "$json_path")
}

cka_sim::state::save() {
  local tmp
  tmp=$(mktemp -t "cka-sim-state.XXXXXX")

  jq -n \
    --argjson version 1 \
    --arg blueprint_id "$CKA_SIM_EXAM_BLUEPRINT_ID" \
    --arg blueprint_path "$CKA_SIM_EXAM_BLUEPRINT_PATH" \
    --arg started_at "$CKA_SIM_EXAM_STARTED_AT" \
    --argjson deadline_ts "$CKA_SIM_EXAM_DEADLINE_TS" \
    --argjson paused_at "$CKA_SIM_EXAM_PAUSED_AT" \
    --argjson paused_seconds "$CKA_SIM_EXAM_PAUSED_SECONDS" \
    --argjson current_question_idx "$CKA_SIM_EXAM_CUR_IDX" \
    --argjson questions "$CKA_SIM_EXAM_QUESTIONS_JSON" \
    --arg final_report_path "$CKA_SIM_EXAM_FINAL_REPORT" \
    '{
      version: $version,
      blueprint: { id: $blueprint_id, path: $blueprint_path },
      started_at: $started_at,
      deadline_ts: $deadline_ts,
      paused_at: $paused_at,
      paused_seconds: $paused_seconds,
      current_question_idx: $current_question_idx,
      questions: $questions,
      final_report_path: $final_report_path
    }' > "$tmp"

  if ! jq empty "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    die "state save: produced invalid JSON"
  fi

  mv -f "$tmp" "$(cka_sim::state::session_path "$CKA_SIM_EXAM_TS")"
}

cka_sim::state::set_question_status() {
  local idx="${1:?set_question_status: idx required}"
  local status="${2:?set_question_status: status required}"
  # If the jq subprocess is interrupted by a signal delivered to the
  # foreground process group (Ctrl-C while a trap is mutating state), it
  # returns empty. Overwriting the global with empty would corrupt state
  # and trip set -e in unrelated callers later. Capture to a local, verify
  # it parses as JSON, only then assign.
  local _new
  _new=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" \
    | jq --argjson i "$idx" --arg s "$status" '.[$i].status = $s' 2>/dev/null) \
    || return 1
  [[ -n "$_new" ]] || return 1
  printf '%s' "$_new" | jq -e empty >/dev/null 2>&1 || return 1
  CKA_SIM_EXAM_QUESTIONS_JSON="$_new"
}

cka_sim::state::record_grade() {
  local idx="${1:?record_grade: idx required}"
  local rc="${2:?record_grade: rc required}"
  local capture="${3:-}"

  local score=0 max_score=0
  local score_line
  score_line=$(printf '%s' "$capture" | grep -oE 'SCORE: [0-9]+/[0-9]+' | head -1 || true)
  if [[ -n "$score_line" ]]; then
    score=$(printf '%s' "$score_line" | grep -oE '[0-9]+' | head -1)
    max_score=$(printf '%s' "$score_line" | grep -oE '[0-9]+' | tail -1)
  fi

  local traps_json
  traps_json=$(cka_sim::state::parse_traps "$capture" | jq -R -s 'split("\n") | map(select(. != ""))')

  CKA_SIM_EXAM_QUESTIONS_JSON=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" \
    | jq --argjson i "$idx" \
         --argjson score "$score" \
         --argjson max "$max_score" \
         --argjson rc "$rc" \
         --argjson traps "$traps_json" \
         --arg raw "$capture" \
         --arg completed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
         '.[$i].score = $score | .[$i].max_score = $max | .[$i].grade_rc = $rc | .[$i].traps = $traps | .[$i].grade_raw = $raw | .[$i].completed_at = $completed | .[$i].status = (if $rc == 0 then "passed" else "failed" end)')
}

cka_sim::state::set_pause() {
  CKA_SIM_EXAM_PAUSED_AT=$(cka_sim::state::now)
}

cka_sim::state::add_pause_delta() {
  local now delta
  now=$(cka_sim::state::now)
  delta=$(( now - CKA_SIM_EXAM_PAUSED_AT ))
  CKA_SIM_EXAM_DEADLINE_TS=$(( CKA_SIM_EXAM_DEADLINE_TS + delta ))
  CKA_SIM_EXAM_PAUSED_SECONDS=$(( CKA_SIM_EXAM_PAUSED_SECONDS + delta ))
  CKA_SIM_EXAM_PAUSED_AT=0
}

cka_sim::state::parse_traps() {
  local capture="${1:-}"
  printf '%s\n' "$capture" \
    | grep -E '^Trap [0-9]+:' \
    | awk -F': *' '{print $2}' \
    || true
}

cka_sim::state::transcript_append() {
  local idx="${1:?transcript_append: idx required}"
  local content="${2:-}"
  local log_file
  log_file="$(cka_sim::state::log_path "$CKA_SIM_EXAM_TS")"
  local qid
  qid=$(printf '%s' "$CKA_SIM_EXAM_QUESTIONS_JSON" | jq -r ".[$idx].id // \"q$idx\"")
  {
    printf '\n=== question %d: %s ===\n' "$((idx + 1))" "$qid"
    printf '%s\n' "$content"
  } >> "$log_file"
}

cka_sim::state::list_sessions() {
  local session_dir
  session_dir="$(cka_sim::state::session_dir)"
  if [[ -d "$session_dir" ]]; then
    find "$session_dir" -maxdepth 1 -name '*.json' -type f | sort -r
  fi
}
