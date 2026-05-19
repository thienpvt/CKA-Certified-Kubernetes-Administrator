#!/bin/bash
# cka-sim audit — Question-intent baseline diff (Phase 16 BASELINE-01).
# Runs each question's setup.sh against a clean live cluster, captures
# actual post-setup state, diffs against expected-symptom.yaml, and emits
# a forensic-friendly per-question table + aggregate summary. Audit-only:
# NOT wired to GHA validate.yml (lint-question-symptom.sh is the CI gate).
#
# Scopes:
#   cka-sim audit                       — all expected-symptom.yaml under packs/
#   cka-sim audit <pack>                — one pack
#   cka-sim audit <pack>/<question>     — single question
#
# Flags:
#   --report path/to.md   Persist same content to a markdown report.
#
# Exit codes:
#   0 = all PASS
#   1 = at least one FAIL
#   2 = preflight error (no live cluster, missing jq/python3/yaml)
set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../symptom-diff.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/symptom-diff.sh"

cka_sim::audit::usage() {
  cat >&2 <<'EOF'
usage: cka-sim audit [--report path/to.md] [<pack>[/<question>]]
  Audit-only forensic question-intent baseline diff. Requires a live cluster.

  Scopes:
    (no positional)            audit all expected-symptom.yaml under cka-sim/packs/
    <pack>                     audit one pack (e.g. storage)
    <pack>/<question>          audit a single question (e.g. storage/01-pvc-binding)

  Flags:
    --report path/to.md        persist same content to a markdown report
    -h | --help                show this message

  Exit codes:
    0  all PASS
    1  at least one FAIL
    2  preflight error (no live cluster, missing jq/python3/yaml)
EOF
}

cka_sim::audit::preflight() {
  if ! kubectl cluster-info >/dev/null 2>&1; then
    err "no live cluster reachable (kubectl cluster-info failed)"
    err "audit requires a live kind+Calico cluster — start one and retry"
    exit 2
  fi
  command -v jq >/dev/null 2>&1 || { err "jq not found in PATH"; exit 2; }
  command -v python3 >/dev/null 2>&1 || { err "python3 not found in PATH"; exit 2; }
  python3 -c 'import yaml' 2>/dev/null || { err "python3 yaml module not available"; exit 2; }
}

# Extract a 3-line excerpt from question.md around a prose match for $name.
# Args: q_dir, name. Prints '  question.md:A-B' line then indented excerpt.
# If no match, prints '  question.md: <no prose match found — review manually>'.
cka_sim::audit::_claim_source() {
  local q_dir="$1" name="$2"
  local qmd="$q_dir/question.md"
  if [[ ! -f "$qmd" ]]; then
    printf '  question.md: <not found>\n'
    return 0
  fi
  local line_num
  line_num="$(grep -nF "$name" "$qmd" | head -1 | cut -d: -f1 || true)"
  if [[ -z "$line_num" ]]; then
    printf '  question.md: <no prose match found for %s>\n' "$name"
    return 0
  fi
  local start=$(( line_num > 1 ? line_num - 1 : 1 ))
  local end=$(( line_num + 1 ))
  printf '  question.md:%s-%s\n' "$start" "$end"
  sed -n "${start},${end}p" "$qmd" | sed 's/^/    /'
}

# Render a per-question block from a TSV stream and append to the buffer.
# Args: pack, q_name, q_dir, tsv_file, rc
# Globals (in/out): _AUDIT_REPORT_BUFFER, _AUDIT_PASS, _AUDIT_FAIL, _AUDIT_ERROR
cka_sim::audit::_render_question() {
  local pack="$1" q_name="$2" q_dir="$3" tsv_file="$4" rc="$5"

  local pass=0 fail=0 missing=0 errors=0 total=0
  local fail_names=()

  if [[ -s "$tsv_file" ]]; then
    while IFS=$'\t' read -r verdict _kind name _jp _exp _act _line; do
      total=$(( total + 1 ))
      case "$verdict" in
        PASS) pass=$(( pass + 1 )) ;;
        FAIL) fail=$(( fail + 1 )); fail_names+=("$name") ;;
        MISSING) missing=$(( missing + 1 )); fail_names+=("$name") ;;
        ERROR) errors=$(( errors + 1 )) ;;
      esac
    done < "$tsv_file"
  fi

  local block=""
  if (( rc == 0 && fail == 0 && missing == 0 && errors == 0 )); then
    # PASS — single line, full table suppressed.
    block="$(printf '✓ %s/%s: PASS (%s/%s expectations met)' "$pack" "$q_name" "$pass" "$total")"
    printf '%s\n' "$block"
    _AUDIT_PASS=$(( _AUDIT_PASS + 1 ))
  else
    # FAIL/ERROR — header + table + Claim source.
    local fcount=$(( fail + missing ))
    block="$(printf '✗ %s/%s: FAIL (%s expectation(s) failed of %s)' "$pack" "$q_name" "$fcount" "$total")"
    printf '%s\n' "$block"
    block+=$'\n'

    # Render the diff table via awk (column-pad).
    if [[ -s "$tsv_file" ]]; then
      local table
      table="$(awk -F'\t' '
        BEGIN {
          h[1]="kind"; h[2]="name"; h[3]="jsonpath"; h[4]="claimed"; h[5]="actual"; h[6]="verdict"
          for (i=1; i<=6; i++) w[i]=length(h[i])
        }
        {
          # Map verdict to glyph: PASS=✓ FAIL=✗ MISSING=? ERROR=!
          v=$1
          glyph=v
          if (v=="PASS") glyph="✓"
          else if (v=="FAIL") glyph="✗"
          else if (v=="MISSING") glyph="?"
          else if (v=="ERROR") glyph="!"
          rows[NR,1]=$2; rows[NR,2]=$3; rows[NR,3]=$4; rows[NR,4]=$5; rows[NR,5]=$6; rows[NR,6]=glyph
          for (i=1; i<=6; i++) if (length(rows[NR,i]) > w[i]) w[i]=length(rows[NR,i])
          n=NR
        }
        END {
          fmt=""
          for (i=1; i<=6; i++) fmt = fmt "%-" w[i] "s" (i==6 ? "\n" : " | ")
          printf fmt, h[1], h[2], h[3], h[4], h[5], h[6]
          sep=""
          for (i=1; i<=6; i++) {
            for (j=0; j<w[i]; j++) sep = sep "-"
            sep = sep (i==6 ? "" : "-+-")
          }
          print sep
          for (r=1; r<=n; r++) printf fmt, rows[r,1], rows[r,2], rows[r,3], rows[r,4], rows[r,5], rows[r,6]
        }
      ' "$tsv_file")"
      printf '%s\n' "$table"
      block+="$table"$'\n'
    fi

    # Claim source block: extract excerpt for first failed name (if any).
    if (( ${#fail_names[@]} > 0 )); then
      local seen_names=()
      printf 'Claim source:\n'
      block+="Claim source:"$'\n'
      local n
      for n in "${fail_names[@]}"; do
        # Dedup names so we don't render the same excerpt multiple times.
        local already=0 s
        for s in "${seen_names[@]}"; do [[ "$s" == "$n" ]] && already=1 && break; done
        (( already == 1 )) && continue
        seen_names+=("$n")
        local excerpt
        excerpt="$(cka_sim::audit::_claim_source "$q_dir" "$n")"
        printf '%s\n' "$excerpt"
        block+="$excerpt"$'\n'
      done
    fi

    if (( errors > 0 )); then
      _AUDIT_ERROR=$(( _AUDIT_ERROR + 1 ))
    else
      _AUDIT_FAIL=$(( _AUDIT_FAIL + 1 ))
    fi
  fi

  _AUDIT_REPORT_BUFFER+="$block"$'\n---\n'
}

cka_sim::audit::main() {
  local report_path=""
  local positional=""

  # Parse args.
  while (( $# > 0 )); do
    case "$1" in
      -h|--help) cka_sim::audit::usage; exit 0 ;;
      --report)
        if [[ $# -lt 2 ]]; then err "--report requires a path"; cka_sim::audit::usage; exit 2; fi
        report_path="$2"; shift 2 ;;
      --report=*)
        report_path="${1#--report=}"; shift ;;
      --*) err "unknown flag: $1"; cka_sim::audit::usage; exit 2 ;;
      *)
        if [[ -n "$positional" ]]; then
          err "unexpected extra argument: $1"; cka_sim::audit::usage; exit 2
        fi
        positional="$1"; shift ;;
    esac
  done

  cka_sim::audit::preflight

  # Build the question list based on the positional arg.
  local yaml_files=()
  if [[ -z "$positional" ]]; then
    while IFS= read -r f; do yaml_files+=("$f"); done < <(find "$CKA_SIM_ROOT/packs" -name 'expected-symptom.yaml' -type f | sort)
  elif [[ "$positional" == */* ]]; then
    local pack="${positional%%/*}"
    local q="${positional#*/}"
    local target="$CKA_SIM_ROOT/packs/$pack/$q/expected-symptom.yaml"
    if [[ ! -f "$target" ]]; then err "no expected-symptom.yaml at $target"; exit 2; fi
    yaml_files=("$target")
  else
    local pack="$positional"
    local pack_dir="$CKA_SIM_ROOT/packs/$pack"
    if [[ ! -d "$pack_dir" ]]; then err "pack not found: $pack_dir"; exit 2; fi
    while IFS= read -r f; do yaml_files+=("$f"); done < <(find "$pack_dir" -name 'expected-symptom.yaml' -type f | sort)
  fi

  if (( ${#yaml_files[@]} == 0 )); then
    warn "no expected-symptom.yaml matched scope '$positional'"
    exit 0
  fi

  header "cka-sim audit"
  info "scope: ${positional:-all}, ${#yaml_files[@]} question(s)"

  # Init aggregate counters and report buffer.
  _AUDIT_PASS=0
  _AUDIT_FAIL=0
  _AUDIT_ERROR=0
  _AUDIT_REPORT_BUFFER=""

  local f q_dir pack q_name tsv_tmp rc
  for f in "${yaml_files[@]}"; do
    q_dir="$(dirname "$f")"
    pack="$(basename "$(dirname "$q_dir")")"
    q_name="$(basename "$q_dir")"

    tsv_tmp="$(mktemp)"
    rc=0
    # Redirect fd 3 to capture structured rows; swallow stderr (lint-style err
    # lines from the lib are noisy for the audit table renderer).
    { cka_sim::symptom_diff::run_one "$f" "$q_dir" "$pack" "$q_name" "audit" 3>"$tsv_tmp"; } 2>/dev/null || rc=$?

    cka_sim::audit::_render_question "$pack" "$q_name" "$q_dir" "$tsv_tmp" "$rc"
    rm -f "$tsv_tmp"
  done

  local total=$(( _AUDIT_PASS + _AUDIT_FAIL + _AUDIT_ERROR ))
  local summary
  summary="$(printf '─── audit summary ───\n%s/%s PASS, %s FAIL, %s errors' \
    "$_AUDIT_PASS" "$total" "$_AUDIT_FAIL" "$_AUDIT_ERROR")"
  printf '\n%s\n' "$summary"
  _AUDIT_REPORT_BUFFER+=$'\n'"$summary"$'\n'

  # Markdown report writer (atomic mktemp + mv).
  if [[ -n "$report_path" ]]; then
    local tmp
    tmp="$(mktemp -t cka-sim-audit-XXXXXX.md)"
    {
      printf '# cka-sim audit report\n\n'
      printf 'Generated: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'Scope: %s\n\n---\n\n' "${positional:-all}"
      printf '%s\n' "$_AUDIT_REPORT_BUFFER"
    } >"$tmp"
    mkdir -p "$(dirname "$report_path")"
    mv "$tmp" "$report_path"
    info "report: $report_path"
  fi

  if (( _AUDIT_FAIL > 0 || _AUDIT_ERROR > 0 )); then
    exit 1
  fi
  exit 0
}

cka_sim::audit::main "$@"
