#!/bin/bash
# cka-sim drill — practice a single question end-to-end (Phase 3).
# Replaces the Phase 1 stub.
#
# Sources: lib/colors.sh, lib/log.sh, lib/preflight.sh
# Does NOT source lib/grade.sh or lib/traps.sh (per RESEARCH Pitfall 5 —
# graders source those themselves as subprocesses).
#
# Orchestration order per TRIP-05:
#   reset.sh -> setup.sh -> prompt -> grade.sh -> EXIT-trap reset.sh
#
# Report file is produced via mktemp + atomic mv (NOT `tee`) per RESEARCH Pitfall 1
# to sidestep SIGPIPE/partial-write races.

set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../preflight.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/preflight.sh"

# ---------- State populated by load_pack / main ----------

declare -g CKA_SIM_PACK_ID="" CKA_SIM_QUESTION_ID="" CKA_SIM_QUESTION_DIR=""
declare -g CKA_SIM_LAB_NS="" CKA_SIM_QUESTION_INDEX="" CKA_SIM_QUESTION_MIN=""
declare -g CKA_SIM_DRILL_TMP=""
declare -g CKA_SIM_DRILL_START_TS=""
declare -ag CKA_SIM_PACK_QUESTION_IDS=()
declare -ag CKA_SIM_PACK_QUESTION_PATHS=()
declare -ag CKA_SIM_PACK_QUESTION_MINUTES=()
declare -gA CKA_SIM_PACK_META=()

# ---------- Usage ----------

cka_sim::drill::usage() {
  cat >&2 <<'EOF'
usage: cka-sim drill <pack> [<n>]
  <pack>  one of: storage workloads-scheduling services-networking cluster-architecture troubleshooting
  <n>     1-based index into the pack's manifest.yaml (default: random)
EOF
}

# ---------- Manifest parser ----------
#
# Pure-bash YAML walker for packs/<pack>/manifest.yaml. Mirrors lib/traps.sh:60-114
# and RESEARCH Pattern 2 lines 201-225.
#
# Populates: CKA_SIM_PACK_QUESTION_IDS[], CKA_SIM_PACK_QUESTION_PATHS[],
#            CKA_SIM_PACK_QUESTION_MINUTES[], CKA_SIM_PACK_META[].
#
# Caller is responsible for clearing the arrays/map beforehand (tests rely on this).
cka_sim::drill::_parse_manifest() {
  local manifest_path="${1:?_parse_manifest: manifest path required}"
  [[ -r "$manifest_path" ]] || die "manifest not readable: $manifest_path"

  local line value
  local in_questions=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines.
    [[ -z "${line//[[:space:]]/}" ]] && continue
    # Skip whole-line comments.
    [[ "${line#"${line%%[![:space:]]*}"}" == "#"* ]] && continue

    # Transition from pack: scope to questions: scope.
    if [[ "$line" =~ ^questions:[[:space:]]*$ ]]; then
      in_questions=1
      continue
    fi

    if (( in_questions == 0 )); then
      # pack: scope — match `^  <key>: <value>`.
      if [[ "$line" =~ ^\ \ ([a-z]+):\ (.+)$ ]]; then
        value="${BASH_REMATCH[2]}"
        # Strip surrounding double-quotes if present (traps.sh:92-96 idiom).
        if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
          value="${value#\"}"
          value="${value%\"}"
        fi
        CKA_SIM_PACK_META["${BASH_REMATCH[1]}"]="$value"
      fi
    else
      # questions: scope — new entry marker, then path/minutes fields.
      if [[ "$line" =~ ^\ \ -\ id:\ (.+)$ ]]; then
        value="${BASH_REMATCH[1]}"
        if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
          value="${value#\"}"; value="${value%\"}"
        fi
        CKA_SIM_PACK_QUESTION_IDS+=("$value")
        CKA_SIM_PACK_QUESTION_PATHS+=("")
        CKA_SIM_PACK_QUESTION_MINUTES+=("")
      elif [[ "$line" =~ ^\ \ \ \ path:\ (.+)$ ]]; then
        value="${BASH_REMATCH[1]}"
        if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
          value="${value#\"}"; value="${value%\"}"
        fi
        local last_p=$(( ${#CKA_SIM_PACK_QUESTION_PATHS[@]} - 1 ))
        (( last_p >= 0 )) && CKA_SIM_PACK_QUESTION_PATHS[$last_p]="$value"
      elif [[ "$line" =~ ^\ \ \ \ estimatedMinutes:\ (.+)$ ]]; then
        value="${BASH_REMATCH[1]}"
        if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
          value="${value#\"}"; value="${value%\"}"
        fi
        local last_m=$(( ${#CKA_SIM_PACK_QUESTION_MINUTES[@]} - 1 ))
        (( last_m >= 0 )) && CKA_SIM_PACK_QUESTION_MINUTES[$last_m]="$value"
      fi
    fi
  done < "$manifest_path"
}

# ---------- Question-index validation ----------
#
# Usage: cka_sim::drill::_validate_picked <picked> <n>
#   Echoes the zero-based index on stdout.
#   Empty <picked>   -> random in [0, n-1]
#   Numeric in [1,n] -> picked - 1
#   Otherwise        -> die (exit 1)
#
# Extracted from load_pack so unit tests can exercise it without file-existence checks.
cka_sim::drill::_validate_picked() {
  local picked="${1:-}" n="${2:?_validate_picked: n required}"
  if [[ -z "$picked" ]]; then
    (( n > 0 )) || die "_validate_picked: n must be > 0 (got $n)"
    printf '%d' $(( RANDOM % n ))
    return 0
  fi
  [[ "$picked" =~ ^[0-9]+$ ]] \
    || die "invalid question index '$picked' (must be a positive integer)"
  (( picked >= 1 && picked <= n )) \
    || die "invalid question index '$picked' (pack has $n questions, use 1-$n)"
  printf '%d' $(( picked - 1 ))
}

# ---------- Load a pack ----------
#
# Resolves the pack manifest, parses it, picks a question (random or 1-based index),
# and sets all downstream state globals + exports. Validates that the question dir
# has the 6 required files and that the 4 script files are executable.
cka_sim::drill::load_pack() {
  local pack="${1:?load_pack: pack required}" picked="${2:-}"
  local manifest="$CKA_SIM_ROOT/packs/$pack/manifest.yaml"
  [[ -r "$manifest" ]] || die "pack manifest not found: $manifest"

  # Reset arrays/map before parsing — load_pack is callable multiple times in theory.
  CKA_SIM_PACK_QUESTION_IDS=()
  CKA_SIM_PACK_QUESTION_PATHS=()
  CKA_SIM_PACK_QUESTION_MINUTES=()
  CKA_SIM_PACK_META=()
  cka_sim::drill::_parse_manifest "$manifest"

  local n=${#CKA_SIM_PACK_QUESTION_IDS[@]}
  (( n > 0 )) || die "pack '$pack' has no questions"

  local idx
  idx=$(cka_sim::drill::_validate_picked "$picked" "$n")

  CKA_SIM_PACK_ID="$pack"
  CKA_SIM_QUESTION_ID="${CKA_SIM_PACK_QUESTION_IDS[$idx]}"
  CKA_SIM_QUESTION_INDEX=$(( idx + 1 ))
  CKA_SIM_QUESTION_DIR="$CKA_SIM_ROOT/packs/$pack/${CKA_SIM_PACK_QUESTION_PATHS[$idx]}"
  CKA_SIM_LAB_NS="cka-sim-${pack}-$(printf '%02d' "$CKA_SIM_QUESTION_INDEX")"
  CKA_SIM_QUESTION_MIN="${CKA_SIM_PACK_QUESTION_MINUTES[$idx]}"

  # Verify 6 required files exist.
  local f
  for f in metadata.yaml question.md setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -e "$CKA_SIM_QUESTION_DIR/$f" ]] \
      || die "missing $f in $CKA_SIM_QUESTION_DIR"
  done
  # Verify 4 script files are executable.
  for f in setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -x "$CKA_SIM_QUESTION_DIR/$f" ]] \
      || die "$CKA_SIM_QUESTION_DIR/$f not executable"
  done

  export CKA_SIM_PACK_ID CKA_SIM_QUESTION_ID CKA_SIM_LAB_NS CKA_SIM_QUESTION_DIR
}

# ---------- Interactive prompt ----------
#
# Reads one line from stdin. EOF or any non-"done" value is treated as "skip"
# (RESEARCH Pitfall 4 — explicit EOF contract). Prompt goes to stderr so stdout
# stays clean for the action token.
cka_sim::drill::prompt_ready() {
  local action=""
  printf '\nType "done" to grade, "skip" to abandon: ' >&2
  if ! IFS= read -r action; then
    action="skip"
  fi
  case "$action" in
    done) printf 'done' ;;
    *)    printf 'skip' ;;
  esac
}

# ---------- EXIT-trap cleanup ----------
#
# Registered as the EXIT trap from main() (NOT from inside this function —
# bash EXIT traps are process-scope, see RESEARCH Pitfall 2 anti-pattern).
# Runs reset.sh to clear the lab namespace on any exit (including skip + grade failure).
cka_sim::drill::cleanup() {
  local rc=$?
  warn "cleaning up lab namespace ${CKA_SIM_LAB_NS:-<unset>}"
  if [[ -n "${CKA_SIM_QUESTION_DIR:-}" && -x "$CKA_SIM_QUESTION_DIR/reset.sh" ]]; then
    bash "$CKA_SIM_QUESTION_DIR/reset.sh" || warn "reset.sh exited non-zero (rc=$?)"
  fi
  [[ -n "${CKA_SIM_DRILL_TMP:-}" ]] && rm -f "$CKA_SIM_DRILL_TMP"
  exit "$rc"
}

# ---------- Report header ----------
#
# Emits the 10-line markdown header that precedes the grade.sh capture in the
# final report file. Sent to stdout so callers can route via redirection.
#
# catalog_version counts catalog entries via a comment-skipping regex
# (^  - id:) — NOT a bare grep -c that would over-count.
cka_sim::drill::render_header() {
  local report="${1:?render_header: report path required}"
  local catalog_version
  catalog_version=$(grep -cE '^[[:space:]]{2}-[[:space:]]+id:' \
    "$CKA_SIM_ROOT/traps/catalog.yaml" 2>/dev/null || echo "0")
  local actual_minutes=0
  if [[ -n "${CKA_SIM_DRILL_START_TS:-}" ]]; then
    actual_minutes=$(( ( $(date +%s) - CKA_SIM_DRILL_START_TS ) / 60 ))
  fi
  cat <<EOF
# cka-sim drill report

- timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- pack: $CKA_SIM_PACK_ID
- question-id: $CKA_SIM_QUESTION_ID
- question-index: $CKA_SIM_QUESTION_INDEX
- lab-ns: $CKA_SIM_LAB_NS
- estimated-minutes: $CKA_SIM_QUESTION_MIN
- actual-minutes: $actual_minutes
- trap-catalog-entries: $catalog_version
- cka-sim-root: $CKA_SIM_ROOT
- report-path: $report

---

EOF
}

# ---------- Main ----------

main() {
  case "${1:-}" in
    -h|--help|"") cka_sim::drill::usage; exit 0 ;;
  esac

  local pack="$1" picked="${2:-}"

  cka_sim::preflight::check_kubeconfig >/dev/null \
    || die "no readable kubeconfig (run 'cka-sim doctor')"
  cka_sim::preflight::check_cluster_nodes >/dev/null \
    || die "cluster topology check failed (run 'cka-sim doctor')"
  mkdir -p "$HOME/.cka-sim/reports"

  cka_sim::drill::load_pack "$pack" "$picked"

  CKA_SIM_DRILL_START_TS=$(date +%s)

  # Trap registered here, NOT inside cleanup (Pitfall 2).
  trap cka_sim::drill::cleanup EXIT

  header "drill: $CKA_SIM_PACK_ID / $CKA_SIM_QUESTION_ID  (lab ns: $CKA_SIM_LAB_NS)"

  info "step 1/4: reset"
  bash "$CKA_SIM_QUESTION_DIR/reset.sh"

  info "step 2/4: setup"
  bash "$CKA_SIM_QUESTION_DIR/setup.sh"

  info "step 3/4: prompt"
  cat "$CKA_SIM_QUESTION_DIR/question.md"
  info "Lab ns: $CKA_SIM_LAB_NS"

  local action
  action=$(cka_sim::drill::prompt_ready)
  if [[ "$action" == "skip" ]]; then
    warn "skipped"
    exit 130
  fi

  info "step 4/4: grade"
  # Capture grade.sh stdout to a tempfile (NOT `| tee`, Pitfall 1).
  CKA_SIM_DRILL_TMP=$(mktemp -t cka-sim-drill-XXXXXX.md)
  local report="$HOME/.cka-sim/reports/$(date -u +%Y%m%dT%H%M%SZ)-$CKA_SIM_PACK_ID-$CKA_SIM_QUESTION_ID.md"
  local grade_rc=0
  bash "$CKA_SIM_QUESTION_DIR/grade.sh" > "$CKA_SIM_DRILL_TMP" || grade_rc=$?

  # Compose header + capture into a .partial, then atomic mv to the final name.
  { cka_sim::drill::render_header "$report"; cat "$CKA_SIM_DRILL_TMP"; } > "$report.partial"
  mv "$report.partial" "$report"

  # Echo the captured grader output to the candidate's stdout.
  cat "$CKA_SIM_DRILL_TMP"
  info "report saved to: $report"

  exit "$grade_rc"
}

# Only run main when this file is executed directly. When sourced (e.g. by unit
# tests that want to call the cka_sim::drill::* helpers in isolation), skip main.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
