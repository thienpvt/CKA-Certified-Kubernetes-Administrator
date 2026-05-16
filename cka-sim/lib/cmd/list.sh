#!/bin/bash
# cka-sim list — show packs, blueprints, history (Phase 7).
# Replaces the Phase 1 stub.

set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../exam-state.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/exam-state.sh"
# shellcheck source=../exam-report.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/exam-report.sh"

cka_sim::list::usage() {
  cat >&2 <<'EOF'
usage: cka-sim list <subcommand>

Subcommands:
  packs       List available domain packs
  blueprints  List available exam blueprints
  history     List completed and in-progress exam sessions
EOF
}

cka_sim::list::packs() {
  local packs_dir="$CKA_SIM_ROOT/packs"
  if [[ ! -d "$packs_dir" ]]; then
    warn "No packs directory found."
    return
  fi
  printf '%s%-25s %s%s\n' "$BOLD" "Pack" "Questions" "$NC"
  printf '%s\n' "─────────────────────────────────────"
  local pack count
  for pack in "$packs_dir"/*/; do
    [[ -d "$pack" ]] || continue
    local name
    name=$(basename "$pack")
    count=$(find "$pack" -mindepth 1 -maxdepth 1 -type d | wc -l)
    printf '%-25s %d\n' "$name" "$count"
  done
}

cka_sim::list::blueprints() {
  local exams_dir="$CKA_SIM_ROOT/../exams"
  if [[ ! -d "$exams_dir" ]]; then
    exams_dir="$(cd "$CKA_SIM_ROOT/.." && pwd)/exams"
  fi
  if [[ ! -d "$exams_dir" ]]; then
    warn "No exams directory found."
    return
  fi
  printf '%s%-20s %s%s\n' "$BOLD" "Blueprint" "Questions" "$NC"
  printf '%s\n' "─────────────────────────────────────"
  local bp manifest count
  for bp in "$exams_dir"/*/; do
    [[ -d "$bp" ]] || continue
    local name
    name=$(basename "$bp")
    manifest="$bp/manifest.yaml"
    if [[ -r "$manifest" ]]; then
      count=$(grep -c 'slug:' "$manifest" 2>/dev/null || echo "?")
    else
      count="?"
    fi
    printf '%-20s %s\n' "$name" "$count"
  done
}

cka_sim::list::history() {
  local sessions
  sessions=$(cka_sim::state::list_sessions)

  if [[ -z "$sessions" ]]; then
    info "No exam history yet. Run 'cka-sim exam <blueprint>' to start."
    return
  fi

  printf '%s%-22s %-18s %-8s %-6s %s%s\n' "$BOLD" "Started" "Blueprint" "Score" "Result" "Status" "$NC"
  printf '%s\n' "──────────────────────────────────────────────────────────────────────────"

  while IFS= read -r json_path; do
    [[ -z "$json_path" || ! -r "$json_path" ]] && continue

    local bp_id started score status result
    bp_id=$(jq -r '.blueprint.id // "—"' "$json_path")
    started=$(jq -r '.started_at // "—"' "$json_path")
    local final_report
    final_report=$(jq -r '.final_report_path // ""' "$json_path")

    if [[ -n "$final_report" && "$final_report" != "null" && "$final_report" != "" ]]; then
      status="complete"
      local questions_json
      questions_json=$(jq -c '.questions' "$json_path")
      local has_scores
      has_scores=$(printf '%s' "$questions_json" | jq '[.[] | select(.score != null)] | length')
      if (( has_scores > 0 )); then
        score=$(cka_sim::report::compute_total "$json_path" 2>/dev/null || echo "?")
        if [[ "$score" =~ ^[0-9]+$ ]] && (( score >= 66 )); then
          result="PASS"
        else
          result="FAIL"
        fi
      else
        score="?"
        result="—"
      fi
    else
      status="(in-progress)"
      score="—"
      result="—"
    fi

    printf '%-22s %-18s %-8s %-6s %s\n' "$started" "$bp_id" "${score}/100" "$result" "$status"
  done <<< "$sessions"
}

cka_sim::list::main() {
  case "${1:-}" in
    -h|--help|"")
      cka_sim::list::usage
      exit 0
      ;;
    packs)
      cka_sim::list::packs
      ;;
    blueprints)
      cka_sim::list::blueprints
      ;;
    history)
      cka_sim::list::history
      ;;
    *)
      err "Unknown subcommand: $1"
      cka_sim::list::usage
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cka_sim::list::main "$@"
fi
