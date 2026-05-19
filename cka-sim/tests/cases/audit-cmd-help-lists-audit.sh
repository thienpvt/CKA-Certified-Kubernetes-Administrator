#!/bin/bash
# tests/cases/audit-cmd-help-lists-audit.sh — Phase 16 BASELINE-01
# Locks: cka-sim help lists the new audit subcommand.
set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

out=$(bash "$CKA_SIM_ROOT/bin/cka-sim" help 2>&1) || true

# Assert exactly one line matching the registered audit help line.
count=$(grep -cE '^  audit ' <<<"$out" || true)
if (( count != 1 )); then
  printf 'FAIL: expected exactly one "  audit " line in help output, got %s\n' "$count" >&2
  printf 'output was:\n%s\n' "$out" >&2
  exit 1
fi

# Assert the registered description is present (locks the wording).
if ! grep -qE '^  audit       Question-intent baseline diff' <<<"$out"; then
  printf 'FAIL: audit help text wording drifted\n' >&2
  printf 'output was:\n%s\n' "$out" >&2
  exit 1
fi

exit 0
