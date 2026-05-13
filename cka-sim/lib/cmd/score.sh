#!/bin/bash
# cka-sim score — view a past session report (Phase 7).
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

cka_sim::score::usage() {
  cat >&2 <<'EOF'
usage: cka-sim score [<ts>]

  <ts>   Session timestamp (e.g., 20260510T090000Z)
         If omitted, shows the most recent session's report.

If the .md report is missing but the .json session exists, regenerates the report.
EOF
}

cka_sim::score::most_recent_ts() {
  local latest
  latest=$(cka_sim::state::list_sessions | head -1)
  [[ -n "$latest" ]] || die "No exam sessions found. Run 'cka-sim exam <blueprint>' first."
  basename "$latest" .json
}

cka_sim::score::main() {
  case "${1:-}" in
    -h|--help)
      cka_sim::score::usage
      exit 0
      ;;
  esac

  local ts="${1:-}"
  if [[ -z "$ts" ]]; then
    ts=$(cka_sim::score::most_recent_ts)
    info "Most recent session: $ts"
  fi

  local report_path json_path
  report_path="$(cka_sim::state::report_path "$ts")"
  json_path="$(cka_sim::state::session_path "$ts")"

  if [[ -r "$report_path" ]]; then
    cat "$report_path"
  elif [[ -r "$json_path" ]]; then
    info "Report missing — regenerating from session data..."
    cka_sim::report::render "$json_path" "$report_path"
    cat "$report_path"
  else
    die "No session found for timestamp: $ts"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cka_sim::score::main "$@"
fi
