#!/bin/bash
# cka-sim/tests/cases/drill_question_selection.sh — verifies
# cka_sim::drill::_validate_picked: 1-based index -> 0-based idx,
# empty picked -> random in-range, out-of-range/non-numeric -> die.

set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"
# shellcheck source=../../lib/cmd/drill.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/cmd/drill.sh"
# drill.sh enables `set -e`; turn it off so accumulated-failure tests work.
set +e

case_failed=0

# ---------- 1-based index selection (n=3) ----------
actual=$(cka_sim::drill::_validate_picked 1 3)
expect_eq "$actual" "0" "picked=1 -> idx=0" || case_failed=1
actual=$(cka_sim::drill::_validate_picked 2 3)
expect_eq "$actual" "1" "picked=2 -> idx=1" || case_failed=1
actual=$(cka_sim::drill::_validate_picked 3 3)
expect_eq "$actual" "2" "picked=3 -> idx=2" || case_failed=1

# ---------- empty picked -> random in [0, n-1] ----------
rand_idx=$(cka_sim::drill::_validate_picked "" 5)
if [[ "$rand_idx" =~ ^[0-4]$ ]]; then
  printf '%s  \xe2\x9c\x93 empty picked -> idx in [0,4]: got %s%s\n' \
    "${GREEN:-}" "$rand_idx" "${NC:-}" >&2
else
  printf '%s  \xe2\x9c\x97 empty picked -> idx out of range: got %s%s\n' \
    "${RED:-}" "$rand_idx" "${NC:-}" >&2
  case_failed=1
fi

# ---------- out-of-range / non-numeric -> die (subshell catches exit 1) ----------
if ( cka_sim::drill::_validate_picked 0 3 ) >/dev/null 2>&1; then
  printf '%s  \xe2\x9c\x97 picked=0 should die but did not%s\n' \
    "${RED:-}" "${NC:-}" >&2
  case_failed=1
else
  printf '%s  \xe2\x9c\x93 picked=0 died as expected%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
fi

if ( cka_sim::drill::_validate_picked 99 3 ) >/dev/null 2>&1; then
  printf '%s  \xe2\x9c\x97 picked=99 (>n) should die but did not%s\n' \
    "${RED:-}" "${NC:-}" >&2
  case_failed=1
else
  printf '%s  \xe2\x9c\x93 picked=99 died as expected%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
fi

if ( cka_sim::drill::_validate_picked abc 3 ) >/dev/null 2>&1; then
  printf '%s  \xe2\x9c\x97 picked=abc should die but did not%s\n' \
    "${RED:-}" "${NC:-}" >&2
  case_failed=1
else
  printf '%s  \xe2\x9c\x93 picked=abc died as expected%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
fi

# ---------- negative number (hyphen fails the ^[0-9]+$ regex) ----------
if ( cka_sim::drill::_validate_picked -1 3 ) >/dev/null 2>&1; then
  printf '%s  \xe2\x9c\x97 picked=-1 should die but did not%s\n' \
    "${RED:-}" "${NC:-}" >&2
  case_failed=1
else
  printf '%s  \xe2\x9c\x93 picked=-1 died as expected%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
fi

exit "$case_failed"
