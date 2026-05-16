#!/bin/bash
# cka-sim/tests/lib/assert.sh — micro-assertions for bash unit cases.
# Sourced by every cka-sim/tests/cases/*.sh.
# Helpers return 0 on pass, 1 on fail; never `die`. The case file's caller
# (run.sh) inspects return codes to aggregate pass/fail.

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
# shellcheck disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"

expect_eq() {
  local actual="${1:-}" expected="${2:-}" msg="${3:-expect_eq}"
  if [[ "$actual" == "$expected" ]]; then
    printf '%s  ✓ %s%s\n' "$GREEN" "$msg" "$NC" >&2
    return 0
  fi
  printf '%s  ✗ %s — expected %q got %q%s\n' "$RED" "$msg" "$expected" "$actual" "$NC" >&2
  return 1
}

expect_empty() {
  local actual="${1:-}" msg="${2:-expect_empty}"
  if [[ -z "$actual" ]]; then
    printf '%s  ✓ %s%s\n' "$GREEN" "$NC" "$msg" >&2
    return 0
  fi
  printf '%s  ✗ %s — expected empty, got %q%s\n' "$RED" "$msg" "$actual" "$NC" >&2
  return 1
}

expect_contains() {
  local haystack="${1:-}" needle="${2:-}" msg="${3:-expect_contains}"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf '%s  ✓ %s%s\n' "$GREEN" "$NC" "$msg" >&2
    return 0
  fi
  printf '%s  ✗ %s — %q does not contain %q%s\n' "$RED" "$msg" "$haystack" "$needle" "$NC" >&2
  return 1
}

expect_match() {
  local actual="${1:-}" pattern="${2:-}" msg="${3:-expect_match}"
  if [[ "$actual" =~ $pattern ]]; then
    printf '%s  ✓ %s%s\n' "$GREEN" "$NC" "$msg" >&2
    return 0
  fi
  printf '%s  ✗ %s — %q does not match /%s/%s\n' "$RED" "$msg" "$actual" "$pattern" "$NC" >&2
  return 1
}
