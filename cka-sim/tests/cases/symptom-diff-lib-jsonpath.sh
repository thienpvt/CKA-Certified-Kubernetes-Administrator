#!/bin/bash
# tests/cases/symptom-diff-lib-jsonpath.sh — Phase 16 BASELINE-01
# Locks: _jsonpath_to_jq translates the three documented input forms.
set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

# shellcheck disable=SC1091
source "$CKA_SIM_ROOT/lib/symptom-diff.sh"

assert_jq() {
  local input="$1" expected="$2" got
  got=$(_jsonpath_to_jq "$input")
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: input=%q\n  expected=%q\n       got=%q\n' "$input" "$expected" "$got" >&2
    exit 1
  fi
}

# Form 1: plain dotted path → prepend a dot.
assert_jq 'status.phase' '.status.phase'

# Form 2: conditions selector → expand to jq pipeline.
assert_jq 'status.conditions[?(@.type=="Available")].status' \
          '.status.conditions[] | select(.type=="Available") | .status'

# Form 3: dotted-key labels → quoted key, escaped dots restored.
assert_jq 'metadata.labels.pod-security\.kubernetes\.io/enforce' \
          '.metadata.labels."pod-security.kubernetes.io/enforce"'

exit 0
