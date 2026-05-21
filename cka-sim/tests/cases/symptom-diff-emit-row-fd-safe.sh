#!/bin/bash
# tests/cases/symptom-diff-emit-row-fd-safe.sh — Phase 22 LINT-01
# Locks: lib/symptom-diff.sh _emit_row is fd-3-safe.
#   Test 1 (lint-mode safety): with fd 3 closed, no `Bad file descriptor`
#                              line leaks to stderr and rc=0.
#   Test 2 (audit-mode preservation): with fd 3 open, exactly one TSV row
#                                     is written, byte-identical to the
#                                     pre-fix printf format.
#   Test 3 (idempotent under repeated lint-mode calls): three back-to-back
#                                                       calls produce zero
#                                                       stderr bytes.
# Per cka-sim/tests/run.sh, this case is sourced in a subshell under
# `set -uo pipefail` (no -e), so accumulating `case_failed` is the correct
# shape; the final `exit "$case_failed"` makes the subshell return non-zero.
set -uo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

# Pre-source the deps that lib/symptom-diff.sh's header comment (lines 5-6)
# documents callers must source themselves. colors.sh -> log.sh -> symptom-diff.sh.
# shellcheck disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck disable=SC1091
source "$CKA_SIM_ROOT/lib/symptom-diff.sh"

if ! declare -F _emit_row >/dev/null 2>&1; then
  printf 'FAIL: _emit_row not declared after sourcing symptom-diff.sh\n' >&2
  exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

case_failed=0

# --- Test 1 (lint-mode safety): fd 3 closed -------------------------------
# In a fresh subshell so any redirect side-effects don't bleed across tests.
( _emit_row PASS pod web .status.phase Running Running 5 ) 2>"$tmp_dir/stderr1.log"
rc1=$?

if [[ "$rc1" -ne 0 ]]; then
  printf '\xE2\x9C\x97 Test 1: expected rc=0 with fd 3 closed, got rc=%s\n' "$rc1" >&2
  case_failed=1
fi
if grep -q 'Bad file descriptor' "$tmp_dir/stderr1.log"; then
  printf '\xE2\x9C\x97 Test 1: stderr leaked `Bad file descriptor` (lint-mode):\n' >&2
  sed 's/^/    /' "$tmp_dir/stderr1.log" >&2
  case_failed=1
fi
if grep -qE 'line (94|95|96|97): 3:' "$tmp_dir/stderr1.log"; then
  printf '\xE2\x9C\x97 Test 1: stderr leaked bash redirect-failure line ref:\n' >&2
  sed 's/^/    /' "$tmp_dir/stderr1.log" >&2
  case_failed=1
fi

# --- Test 2 (audit-mode preservation): fd 3 open --------------------------
printf 'FAIL\tsvc\tweb\t.spec.type\tClusterIP\tNodePort\t12\n' > "$tmp_dir/expected.tsv"

( _emit_row FAIL svc web .spec.type ClusterIP NodePort 12 3>"$tmp_dir/audit.tsv" )
rc2=$?

if [[ "$rc2" -ne 0 ]]; then
  printf '\xE2\x9C\x97 Test 2: expected rc=0 with fd 3 open, got rc=%s\n' "$rc2" >&2
  case_failed=1
fi
audit_lines=$(wc -l < "$tmp_dir/audit.tsv" 2>/dev/null || echo 0)
audit_lines=${audit_lines// /}
if [[ "$audit_lines" != "1" ]]; then
  printf '\xE2\x9C\x97 Test 2: expected exactly 1 TSV line on fd 3, got %s\n' "$audit_lines" >&2
  sed 's/^/    /' "$tmp_dir/audit.tsv" >&2 || true
  case_failed=1
fi
if ! diff -q "$tmp_dir/audit.tsv" "$tmp_dir/expected.tsv" >/dev/null 2>&1; then
  printf '\xE2\x9C\x97 Test 2: audit-mode TSV row diverges from expected printf shape\n' >&2
  printf '    expected:\n' >&2; sed 's/^/      /' "$tmp_dir/expected.tsv" >&2
  printf '    got:\n' >&2;      sed 's/^/      /' "$tmp_dir/audit.tsv" >&2
  case_failed=1
fi

# --- Test 3 (no leak across repeated lint-mode calls) ---------------------
: > "$tmp_dir/stderr3.log"
for _ in 1 2 3; do
  ( _emit_row PASS x y z a b c ) 2>>"$tmp_dir/stderr3.log"
done

if [[ -s "$tmp_dir/stderr3.log" ]]; then
  printf '\xE2\x9C\x97 Test 3: lint-mode loop leaked stderr (must be zero bytes):\n' >&2
  sed 's/^/    /' "$tmp_dir/stderr3.log" >&2
  case_failed=1
fi

exit "$case_failed"
