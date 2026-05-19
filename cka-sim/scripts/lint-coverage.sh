#!/bin/bash
# cka-sim/scripts/lint-coverage.sh -- PACK-07 coverage-matrix lint.
# Verifies each pack's coverage.yaml lists >=1 question per Tracker slug, and
# every listed question-id appears in manifest.yaml. Emits warnings for orphan
# manifest questions (declared but not referenced in any tracker slug).
#
# Pure bash per D-04 (no python, no yq).
# Mirror of cka-sim/scripts/lint-packs.sh shape. Wired into validate-local.sh
# in Plan 04-16 after Wave 3 populates the live manifests.
#
# Usage: lint-coverage.sh              -- lint every pack under packs/
#        lint-coverage.sh <pack-slug>  -- lint one pack
# Exit:  0 on success, 1 if any tracker slug has 0 questions or any referenced
#        question-id is not in the pack's manifest.

set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "coverage lint"

# Test-mode override: unit cases point this at a fixture tree.
PACKS_DIR="${CKA_SIM_LINT_PACKS_DIR:-$CKA_SIM_ROOT/packs}"

if [[ ! -d "$PACKS_DIR" ]]; then
  warn "no packs dir at $PACKS_DIR -- skipping lint"
  exit 0
fi

target_pack="${1:-}"

errors=0
warnings=0
checked=0

# _parse_manifest_questions <manifest.yaml> -> populates $MANIFEST_IDS (newline-separated)
_parse_manifest_questions() {
  local mf="$1"
  MANIFEST_IDS=""
  local line
  local in_questions=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^questions:[[:space:]]*$ ]] && { in_questions=1; continue; }
    # Exit questions block on any top-level key line (starts with letter, no leading ws).
    if (( in_questions == 1 )) && [[ "$line" =~ ^[a-zA-Z] ]]; then
      in_questions=0
    fi
    if (( in_questions == 1 )) && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+id:[[:space:]]+(.+)$ ]]; then
      MANIFEST_IDS+="${BASH_REMATCH[1]}"$'\n'
    fi
  done < "$mf"
}

# _parse_coverage <coverage.yaml> -> populates:
#   COVERAGE_TRACKERS  = newline-separated slug names
#   COVERAGE_REFS      = newline-separated <slug>=<qid> pairs
_parse_coverage() {
  local cf="$1"
  COVERAGE_TRACKERS=""
  COVERAGE_REFS=""
  local line current_slug=""
  local in_tracker=0 in_questions=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Blank / comment-only
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "${line#"${line%%[![:space:]]*}"}" == "#"* ]] && continue
    # top-level `tracker:` enters tracker section
    if [[ "$line" =~ ^tracker:[[:space:]]*$ ]]; then in_tracker=1; continue; fi
    # top-level key (starts with letter, no leading ws) exits tracker section
    if (( in_tracker == 1 )) && [[ "$line" =~ ^[a-zA-Z] ]]; then in_tracker=0; continue; fi
    # 2-space slug header (new tracker entry)
    if (( in_tracker == 1 )) && [[ "$line" =~ ^\ \ ([a-z][a-z0-9-]*):[[:space:]]*$ ]]; then
      current_slug="${BASH_REMATCH[1]}"
      COVERAGE_TRACKERS+="$current_slug"$'\n'
      in_questions=0
      continue
    fi
    # 4-space `questions:` opens the list (block-list form only; flow-list `questions: []` deliberately unsupported -> empty-tracker error)
    if (( in_tracker == 1 )) && [[ "$line" =~ ^\ {4}questions:[[:space:]]*$ ]]; then in_questions=1; continue; fi
    # 6-space `- <qid>` list item
    if (( in_questions == 1 )) && [[ "$line" =~ ^\ {6}-[[:space:]]+(.+)$ ]]; then
      local qid="${BASH_REMATCH[1]}"
      qid="${qid%\"}"; qid="${qid#\"}"
      qid="${qid%\'}"; qid="${qid#\'}"
      COVERAGE_REFS+="${current_slug}=${qid}"$'\n'
      continue
    fi
    # Any other 4-space key ends the questions list for this slug
    if (( in_questions == 1 )) && [[ "$line" =~ ^\ {4}[a-z] ]]; then in_questions=0; fi
  done < "$cf"
}

_in_list() {
  local needle="$1" list="$2" item
  while IFS= read -r item; do
    [[ "$item" == "$needle" ]] && return 0
  done <<< "$list"
  return 1
}

for pack_dir in "$PACKS_DIR"/*/; do
  [[ -d "$pack_dir" ]] || continue
  pack_id=$(basename "$pack_dir")
  [[ -n "$target_pack" && "$pack_id" != "$target_pack" ]] && continue
  mf="${pack_dir}manifest.yaml"
  cf="${pack_dir}coverage.yaml"
  if [[ ! -f "$mf" ]]; then
    err "$pack_id: missing manifest.yaml"
    errors=$(( errors + 1 ))
    continue
  fi
  if [[ ! -f "$cf" ]]; then
    warn "$pack_id: no coverage.yaml yet -- skipping (expected during scaffold)"
    continue
  fi
  checked=$(( checked + 1 ))
  _parse_manifest_questions "$mf"
  _parse_coverage "$cf"
  # Check 1: coverage file has any tracker entries at all
  if [[ -z "${COVERAGE_TRACKERS%$'\n'}" ]]; then
    err "$pack_id: coverage.yaml has no tracker entries"
    errors=$(( errors + 1 ))
    continue
  fi
  # Check 2: every tracker slug has >=1 question referenced
  while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue
    slug_has_ref=0
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      if [[ "$ref" == "${slug}="* ]]; then slug_has_ref=1; break; fi
    done <<< "$COVERAGE_REFS"
    if (( slug_has_ref == 0 )); then
      err "$pack_id: tracker slug '$slug' has empty questions list"
      errors=$(( errors + 1 ))
    fi
  done <<< "$COVERAGE_TRACKERS"
  # Check 3: every referenced question-id exists in manifest
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    qid="${ref#*=}"
    if ! _in_list "$qid" "$MANIFEST_IDS"; then
      err "$pack_id: question-id '$qid' referenced in coverage.yaml is not in manifest.yaml"
      errors=$(( errors + 1 ))
    fi
  done <<< "$COVERAGE_REFS"
  # Check 4 (warning, non-fatal): orphan manifest question
  while IFS= read -r qid; do
    [[ -z "$qid" ]] && continue
    orphan=1
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      if [[ "${ref#*=}" == "$qid" ]]; then orphan=0; break; fi
    done <<< "$COVERAGE_REFS"
    if (( orphan == 1 )); then
      warn "$pack_id: question '$qid' declared in manifest.yaml but not referenced in coverage.yaml (orphan)"
      warnings=$(( warnings + 1 ))
    fi
  done <<< "$MANIFEST_IDS"
  ok "$pack_id: coverage schema OK"
done

printf '\n' >&2
if (( errors > 0 )); then
  err "$errors coverage error(s), $warnings warning(s) across $checked pack(s). Fix before pushing."
  exit 1
fi
ok "coverage lint passed ($checked pack(s), $warnings warning(s))."
exit 0
