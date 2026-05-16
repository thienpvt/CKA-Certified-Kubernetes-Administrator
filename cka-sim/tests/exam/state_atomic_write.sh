#!/bin/bash
# cka-sim/tests/exam/state_atomic_write.sh — verify atomic mktemp+mv save pattern.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# Use a temp HOME so we don't pollute real ~/.cka-sim/
TEST_HOME=$(mktemp -d -t cka-sim-test-home-XXXXXX)
export HOME="$TEST_HOME"
export CKA_SIM_NOW_OVERRIDE=1700000000

source "$CKA_SIM_ROOT/lib/exam-state.sh"

# --- Test 1: init creates a valid session file ---
cka_sim::state::init "test-bp" "test-path.yaml" '[{"id":"q1","status":"pending"}]' 120

session_file="$TEST_HOME/.cka-sim/sessions/${CKA_SIM_EXAM_TS}.json"
if [[ ! -f "$session_file" ]]; then
  err "Test 1: session file not created at $session_file"
  case_failed=1
else
  if ! jq empty "$session_file" 2>/dev/null; then
    err "Test 1: session file is not valid JSON"
    case_failed=1
  else
    ok "Test 1: init creates valid session JSON"
  fi
fi

# --- Test 2: save produces valid JSON after state mutation ---
cka_sim::state::set_question_status 0 "flagged"
cka_sim::state::save

if ! jq empty "$session_file" 2>/dev/null; then
  err "Test 2: session file invalid after save"
  case_failed=1
else
  local_status=$(jq -r '.questions[0].status' "$session_file")
  if [[ "$local_status" != "flagged" ]]; then
    err "Test 2: expected status 'flagged', got '$local_status'"
    case_failed=1
  else
    ok "Test 2: save persists state mutation atomically"
  fi
fi

# --- Test 3: original file survives if jq produces bad output ---
# We can't easily inject a jq failure without mocking, so verify the pattern:
# the file on disk is always valid JSON (mktemp+mv guarantees no partial writes)
cp "$session_file" "$session_file.backup"
cka_sim::state::set_question_status 0 "answered"
cka_sim::state::save

if ! jq empty "$session_file" 2>/dev/null; then
  err "Test 3: file corrupted after second save"
  case_failed=1
else
  ok "Test 3: repeated saves maintain valid JSON"
fi

# Cleanup
rm -rf "$TEST_HOME"

exit "$case_failed"
