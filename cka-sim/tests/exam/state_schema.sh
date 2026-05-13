#!/bin/bash
# cka-sim/tests/exam/state_schema.sh — verify schema version check on load.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

TEST_HOME=$(mktemp -d -t cka-sim-test-home-XXXXXX)
export HOME="$TEST_HOME"
export CKA_SIM_NOW_OVERRIDE=1700000000

source "$CKA_SIM_ROOT/lib/exam-state.sh"

SESSION_DIR="$TEST_HOME/.cka-sim/sessions"
mkdir -p "$SESSION_DIR"

# --- Test 1: version 2 is rejected ---
cat > "$SESSION_DIR/20260101T000000Z.json" <<'EOF'
{
  "version": 2,
  "blueprint": {"id": "test", "path": "test.yaml"},
  "started_at": "2026-01-01T00:00:00Z",
  "deadline_ts": 1700007200,
  "paused_at": 0,
  "paused_seconds": 0,
  "current_question_idx": 0,
  "questions": [],
  "final_report_path": ""
}
EOF

set +e
out=$(cka_sim::state::load "20260101T000000Z" 2>&1)
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  err "Test 1: load should reject version 2 but exited 0"
  case_failed=1
else
  ok "Test 1: version 2 rejected (rc=$rc)"
fi

# --- Test 2: missing blueprint field causes jq to return null (graceful) ---
cat > "$SESSION_DIR/20260102T000000Z.json" <<'EOF'
{
  "version": 1,
  "started_at": "2026-01-02T00:00:00Z",
  "deadline_ts": 1700007200,
  "paused_at": 0,
  "paused_seconds": 0,
  "current_question_idx": 0,
  "questions": [],
  "final_report_path": ""
}
EOF

set +e
out=$(cka_sim::state::load "20260102T000000Z" 2>&1)
rc=$?
set -e

# This should succeed (version is 1) but blueprint.id will be "null"
if [[ "$rc" -ne 0 ]]; then
  err "Test 2: load failed on missing blueprint (rc=$rc) — expected graceful null"
  case_failed=1
else
  ok "Test 2: missing blueprint field loads gracefully (null)"
fi

# --- Test 3: valid v1 session loads correctly ---
cat > "$SESSION_DIR/20260103T000000Z.json" <<'EOF'
{
  "version": 1,
  "blueprint": {"id": "bp-test", "path": "bp.yaml"},
  "started_at": "2026-01-03T00:00:00Z",
  "deadline_ts": 1700007200,
  "paused_at": 0,
  "paused_seconds": 300,
  "current_question_idx": 5,
  "questions": [{"id":"q1","status":"pending"}],
  "final_report_path": "/tmp/report.md"
}
EOF

set +e
cka_sim::state::load "20260103T000000Z" 2>/dev/null
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  err "Test 3: valid v1 session failed to load (rc=$rc)"
  case_failed=1
elif [[ "$CKA_SIM_EXAM_BLUEPRINT_ID" != "bp-test" ]]; then
  err "Test 3: blueprint_id expected 'bp-test', got '$CKA_SIM_EXAM_BLUEPRINT_ID'"
  case_failed=1
elif [[ "$CKA_SIM_EXAM_CUR_IDX" != "5" ]]; then
  err "Test 3: cur_idx expected 5, got '$CKA_SIM_EXAM_CUR_IDX'"
  case_failed=1
elif [[ "$CKA_SIM_EXAM_PAUSED_SECONDS" != "300" ]]; then
  err "Test 3: paused_seconds expected 300, got '$CKA_SIM_EXAM_PAUSED_SECONDS'"
  case_failed=1
else
  ok "Test 3: valid v1 session loads correctly"
fi

rm -rf "$TEST_HOME"
exit "$case_failed"
