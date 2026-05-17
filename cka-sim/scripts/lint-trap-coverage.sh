#!/bin/bash
# cka-sim/scripts/lint-trap-coverage.sh — cross-file lint: every metadata.yaml `traps:` entry
# must have a matching `cka_sim::grade::record_trap <id>` (or quoted-literal) call in the
# sibling grade.sh. Pure bash (per D-04 — no python, no yq).
#
# Edge case: if a grade.sh uses the dynamic id pattern `record_trap "$var"` (e.g.
# cluster-architecture/04-pss-enforce uses `"$hit"`, storage/01 uses `"$tid"`), the lint
# cannot statically prove coverage of any specific trap id. In that case all declared
# traps for that question are treated as covered and a one-line warn is emitted so authors
# see the limitation. Stricter "no dynamic-id" enforcement is deferred (Phase 12 deferred
# ideas in 12-CONTEXT.md).
#
# Wired into cka-sim/scripts/test.sh and CI's bash-tests job by plan 12-05.

set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "trap coverage lint"

# Test-mode override (mirrors lint-packs.sh / lint-coverage.sh).
PACKS_DIR="${CKA_SIM_LINT_PACKS_DIR:-$CKA_SIM_ROOT/packs}"

if [[ ! -d "$PACKS_DIR" ]]; then
  warn "no packs dir at $PACKS_DIR — skipping lint"
  exit 0
fi

errors=0
checked=0
warned=0

_strip_quotes() {
  local v="$1"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  printf '%s' "$v"
}

# _parse_traps <metadata.yaml> -> populates two parallel newline-separated lists:
#   PARSED_TRAP_IDS    — one trap id per line
#   PARSED_TRAP_LINES  — one line number per line, same index as PARSED_TRAP_IDS
# Block-list state machine: enter `traps:` block on top-level `traps:` line, exit on
# next top-level key (line starts with letter, no leading whitespace).
_parse_traps() {
  local mf="$1"
  PARSED_TRAP_IDS=""
  PARSED_TRAP_LINES=""
  local line lineno=0 in_traps=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$(( lineno + 1 ))
    # Comment / blank
    [[ -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" =~ ^[[:space:]]*# ]]; then continue; fi
    # Enter traps: block
    if [[ "$line" =~ ^traps:[[:space:]]*$ ]]; then
      in_traps=1
      continue
    fi
    # Exit on next top-level key (any letter at column 0 — references:, etc.)
    if (( in_traps == 1 )) && [[ "$line" =~ ^[a-zA-Z] ]]; then
      in_traps=0
      continue
    fi
    # 2-space `  - <id>` list item inside the traps: block
    if (( in_traps == 1 )) && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
      local raw="${BASH_REMATCH[1]}"
      # Strip a trailing inline comment if any: "id  # foo" -> "id"
      raw="${raw%%#*}"
      # Strip trailing whitespace
      raw="${raw%"${raw##*[![:space:]]}"}"
      local id
      id="$(_strip_quotes "$raw")"
      [[ -z "$id" ]] && continue
      PARSED_TRAP_IDS+="$id"$'\n'
      PARSED_TRAP_LINES+="$lineno"$'\n'
    fi
  done < "$mf"
}

# _grade_uses_dynamic_form <grade.sh> -> rc 0 if the file contains `record_trap "$var"`.
_grade_uses_dynamic_form() {
  local gs="$1"
  grep -nE 'record_trap[[:space:]]+"\$' "$gs" >/dev/null 2>&1
}

# _grade_records_literal <grade.sh> <id> -> rc 0 if the file contains
#   `record_trap <id>` (bare) OR `record_trap "<id>"` (quoted-literal).
# Uses grep -F (literal) per CONTEXT.md decision — avoids regex quoting headaches.
_grade_records_literal() {
  local gs="$1" id="$2"
  grep -F "record_trap $id" "$gs" >/dev/null 2>&1 && return 0
  grep -F "record_trap \"$id\"" "$gs" >/dev/null 2>&1 && return 0
  return 1
}

# Walk packs/<domain>/<NN>-*/. Question dirs are exactly the ones whose basename starts
# with a digit; skip _template, README, manifest.yaml, coverage.yaml, etc.
for domain_dir in "$PACKS_DIR"/*/; do
  [[ -d "$domain_dir" ]] || continue
  domain_name=$(basename "$domain_dir")
  for q_dir in "$domain_dir"*/; do
    [[ -d "$q_dir" ]] || continue
    q_name=$(basename "$q_dir")
    # Skip non-question dirs
    case "$q_name" in
      _template|.*) continue ;;
    esac
    [[ "$q_name" =~ ^[0-9] ]] || continue
    mf="${q_dir}metadata.yaml"
    gs="${q_dir}grade.sh"
    if [[ ! -f "$mf" ]]; then
      continue
    fi
    if [[ ! -f "$gs" ]]; then
      err "$domain_name/$q_name: metadata.yaml present but grade.sh missing"
      errors=$(( errors + 1 ))
      continue
    fi
    checked=$(( checked + 1 ))
    _parse_traps "$mf"
    # Empty traps: list — nothing to verify, count as ok.
    if [[ -z "${PARSED_TRAP_IDS%$'\n'}" ]]; then
      ok "$domain_name/$q_name: no traps declared"
      continue
    fi
    # Dynamic-id grade.sh: assume coverage, emit warn.
    if _grade_uses_dynamic_form "$gs"; then
      warn "$domain_name/$q_name: grade.sh uses dynamic record_trap \"\$var\"; coverage assumed for all declared traps"
      warned=$(( warned + 1 ))
      ok "$domain_name/$q_name: trap coverage assumed (dynamic id)"
      continue
    fi
    # Static check: every declared id must appear as a literal record_trap call.
    # NOTE: bare names (no `local`) — this block runs at script top-level, not inside a function;
    # `local` would error with "local: can only be used in a function" under set -e (matches the
    # pattern lint-traps.sh comments at line 176-177).
    local_orphans=0
    while IFS= read -r id <&3 && IFS= read -r lineno <&4; do
      [[ -z "$id" ]] && continue
      if ! _grade_records_literal "$gs" "$id"; then
        err "$domain_name/$q_name/metadata.yaml:$lineno: trap '$id' declared but no record_trap call in grade.sh"
        errors=$(( errors + 1 ))
        local_orphans=$(( local_orphans + 1 ))
      fi
    done 3<<<"$PARSED_TRAP_IDS" 4<<<"$PARSED_TRAP_LINES"
    if (( local_orphans == 0 )); then
      ok "$domain_name/$q_name: trap coverage OK"
    fi
  done
done

printf '\n' >&2
if (( errors > 0 )); then
  err "$errors trap-coverage error(s) across $checked question(s) ($warned dynamic-id warning(s)). Fix before pushing."
  exit 1
fi
ok "trap coverage lint passed ($checked question(s) checked, $warned dynamic-id warning(s))."
exit 0
