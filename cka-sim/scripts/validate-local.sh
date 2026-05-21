#!/bin/bash
# cka-sim/scripts/validate-local.sh — yamllint + shellcheck for all cka-sim files.
# Run locally before pushing. Also invoked by CI shellcheck job.

set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "validate-local"

errors=0

# Pass 1: yamllint
# Plan 23-01 BLG-06: line-length max bumped 200 -> 500. catalog.yaml description
# fields are deliberately verbose single-line strings (~420 chars worst case);
# folding via YAML scalars would change on-disk representation without improving
# readability. See .planning/phases/23-gha-environmental-forensics-lint-triage/
# 23-01-FINDINGS.md for the audit trail.
info "pass 1: yamllint — cka-sim/**/*.yaml"
while IFS= read -r f; do
  if ! yamllint -d '{extends: default, rules: {line-length: {max: 500}, truthy: disable, document-start: disable, comments-indentation: disable, indentation: {indent-sequences: whatever}}}' "$f" 2>/dev/null; then
    err "yamllint FAIL: $f"
    errors=$(( errors + 1 ))
  fi
done < <(find "$CKA_SIM_ROOT" -name '*.yaml' -o -name '*.yml')

# Pass 2: shellcheck — opt out via CKA_SIM_SKIP_SHELLCHECK=1 for hosts without shellcheck installed.
if [[ -n "${CKA_SIM_SKIP_SHELLCHECK:-}" ]]; then
  warn "pass 2: shellcheck SKIPPED (CKA_SIM_SKIP_SHELLCHECK is set)"
elif ! command -v shellcheck >/dev/null 2>&1; then
  warn "pass 2: shellcheck SKIPPED (binary not in PATH; install via apt/brew/choco to enable)"
else
  info "pass 2: shellcheck — cka-sim/**/*.sh"
  # Plan 23-01 BLG-06: exclude tests/fixtures/exam/packs/ — intentionally-malformed
  # grader fixtures (mock-pack-alpha/*/grade.sh) used to test the exam runner's
  # handling of broken graders. They deliberately use printf with no format
  # specifiers (SC2182) and a positional arg to confirm it is silently dropped.
  while IFS= read -r f; do
    if ! shellcheck -x -s bash "$f" 2>/dev/null; then
      err "shellcheck FAIL: $f"
      errors=$(( errors + 1 ))
    fi
  done < <(find "$CKA_SIM_ROOT" -name '*.sh' -not -path '*/tests/fixtures/exam/packs/*')
fi

printf '\n' >&2
if (( errors > 0 )); then
  err "$errors file(s) failed validation"
  exit 1
fi

ok "validate-local passed"
exit 0
