#!/bin/bash
# cka-sim/tests/exam/report_golden.sh — golden-file integration test for report rendering.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

REAL_ROOT="$CKA_SIM_ROOT"
source "$REAL_ROOT/tests/lib/assert.sh"

case_failed=0

FIXTURES="$REAL_ROOT/tests/fixtures/exam"

# Source report module while CKA_SIM_ROOT still points to real root (so colors/log resolve)
source "$REAL_ROOT/lib/exam-report.sh" 2>/dev/null || true

# Now override CKA_SIM_ROOT so traps/catalog.yaml lookup uses fixture path
export CKA_SIM_ROOT="$FIXTURES"

SESSION_JSON="$FIXTURES/session-fixture.json"
EXPECTED="$FIXTURES/expected-report.md"
TMP_OUTPUT=$(mktemp -t cka-sim-report-golden-XXXXXX.md)

# --- Test 1: render produces output matching golden file ---
cka_sim::report::render "$SESSION_JSON" "$TMP_OUTPUT" 2>/dev/null

if diff -u "$EXPECTED" "$TMP_OUTPUT" > /dev/null 2>&1; then
  ok "Test 1: report output matches golden file"
else
  err "Test 1: report output differs from golden file"
  diff -u "$EXPECTED" "$TMP_OUTPUT" | head -40 >&2
  case_failed=1
fi

# --- Test 2: total score is 64 (FAIL) ---
total=$(cka_sim::report::compute_total "$SESSION_JSON" 2>/dev/null)
if [[ "$total" == "64" ]]; then
  ok "Test 2: compute_total = 64 (correct)"
else
  err "Test 2: compute_total expected 64, got '$total'"
  case_failed=1
fi

# --- Test 3: report contains all required sections ---
for section in "Per-Domain Breakdown" "Top 5 Traps Hit" "Suggested Next Drills" "Question-by-Question Detail"; do
  if grep -q "$section" "$TMP_OUTPUT"; then
    ok "Test 3: section '$section' present"
  else
    err "Test 3: missing section '$section'"
    case_failed=1
  fi
done

rm -f "$TMP_OUTPUT"
export CKA_SIM_ROOT="$REAL_ROOT"
exit "$case_failed"
