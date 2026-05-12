#!/bin/bash
# cka-sim/scripts/lint-deprecated-strings.sh — fail any cka-sim/packs/ file that
# contains a forbidden (deprecated/removed-API) string outside a comment/prose
# carveout. Extends the CI lint contract per Phase 5 RESEARCH §13.
#
# Forbidden strings (v1.35 exam-wrong):
#   1. PodSecurityPolicy         — removed in 1.25; use PodSecurity admission
#   2. --container-runtime=remote — removed in 1.27; use --container-runtime-endpoint
#   3. policy/v1beta1            — removed in 1.25; use policy/v1
#   4. gitRepo:                  — removed volume type; use init-container + emptyDir
#   5. dockershim                — removed in 1.24; use containerd/CRI-O/cri-dockerd
#
# Carveouts:
#   - YAML / sh line comments: first non-whitespace char is '#' (the lint walker
#     still fires if the forbidden string appears OUTSIDE a comment on the same
#     line, but bare '#'-prefixed reference lines are skipped).
#   - Markdown prose: in .md files, lines OUTSIDE fenced code blocks labelled
#     yaml|bash|sh|shell are considered prose and allowed. Hits INSIDE those
#     fenced blocks still fire. Tracked via a small awk state machine.
#
# Exit 0 on clean, non-zero on violation (exit code = failure count, capped at 125).

set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "deprecated-strings lint"

# Test-mode override: unit cases point this at a fixture tree.
PACKS_DIR="${CKA_SIM_LINT_PACKS_DIR:-$CKA_SIM_ROOT/packs}"

if [[ ! -d "$PACKS_DIR" ]]; then
  warn "no packs dir at $PACKS_DIR — skipping lint (expected during scaffold)"
  exit 0
fi

# Forbidden patterns. Double-hyphen in pattern 2 is escaped to prevent grep's
# long-option parsing from confusing `--container-runtime=remote` with a flag.
patterns=(
  "PodSecurityPolicy"
  "\\-\\-container-runtime=remote"
  "policy/v1beta1"
  "gitRepo:"
  "dockershim"
)

# File scope: yaml, sh, md under the packs dir.
mapfile -t files < <(find "$PACKS_DIR" -type f \( -name '*.yaml' -o -name '*.sh' -o -name '*.md' \))

failures=0
checked=0

for p in "${patterns[@]}"; do
  for file in "${files[@]}"; do
    checked=$(( checked + 1 ))
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      line_num="${hit%%:*}"
      rest="${hit#*:}"
      # Carveout 1: YAML/sh line comment (first non-ws char is '#').
      stripped="${rest#"${rest%%[![:space:]]*}"}"
      if [[ "${stripped:0:1}" == "#" ]]; then
        continue
      fi
      # Carveout 2: markdown prose outside fenced yaml/bash/sh/shell blocks.
      if [[ "$file" == *.md ]]; then
        in_code=$(awk -v target="$line_num" '
          /^```(yaml|bash|sh|shell)[[:space:]]*$/ { code=1; next }
          /^```[[:space:]]*$/                     { code=0; next }
          NR==target                              { print code; exit }
        ' "$file")
        if [[ "$in_code" != "1" ]]; then
          continue
        fi
      fi
      err "LINT FAIL: $file:$line_num: $rest"
      failures=$(( failures + 1 ))
    done < <(grep -nE "$p" "$file" 2>/dev/null || true)
  done
done

printf '\n' >&2
if (( failures > 0 )); then
  err "$failures deprecated-string violation(s). Fix before pushing."
  # Cap exit code at 125 so it stays inside bash's usable range.
  (( failures > 125 )) && failures=125
  exit "$failures"
fi
ok "deprecated-strings lint passed ($checked file-pattern check(s))."
exit 0
