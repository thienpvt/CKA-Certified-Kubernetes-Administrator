#!/bin/bash
# Phase 7 UAT — run all test cases on the live cluster.
# Usage: bash cka-sim/tests/phase7-uat.sh
# Results appended to: cka-sim/results.txt
#
# Prerequisites:
#   - On the control-plane node with the repo cloned
#   - Cluster is healthy (cka-sim doctor passes)
#   - All 5 domain packs are deployed (Phases 4-6 complete)

set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT
REPO_ROOT="$(cd "$CKA_SIM_ROOT/.." && pwd)"
CKA_SIM="$CKA_SIM_ROOT/bin/cka-sim"
RESULTS_FILE="$CKA_SIM_ROOT/results.txt"

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"

header "Phase 7 UAT — Exam Mode + Blueprint Alpha + Reporting"

total=0
passed=0
failed=0

log_result() {
  printf '%s\n' "$1" | tee -a "$RESULTS_FILE"
}

pass() { passed=$((passed+1)); total=$((total+1)); ok "PASS: $1"; log_result "[phase7] PASS: $1"; }
fail() { failed=$((failed+1)); total=$((total+1)); err "FAIL: $1 — $2"; log_result "[phase7] FAIL: $1 — $2"; }

log_result ""
log_result "==================== Phase 7 UAT: Exam Mode + Blueprint Alpha + Reporting ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ===================="

# ─────────────────────────────────────────────────────────────────────
# Test 3: Blueprint composition (automated)
# ─────────────────────────────────────────────────────────────────────
info "Test 3: Blueprint composition"

q_count=$(grep -c 'slug:' "$REPO_ROOT/exams/blueprint-alpha/manifest.yaml" 2>/dev/null || echo 0)
if (( q_count == 17 )); then
  pass "Test 3a: manifest has 17 questions"
else
  fail "Test 3a: manifest question count" "expected 17, got $q_count"
fi

lint_out=$(bash "$CKA_SIM_ROOT/scripts/lint-packs.sh" 2>&1)
if echo "$lint_out" | grep -q 'pack lint passed'; then
  pass "Test 3b: lint-packs pass H passes"
else
  fail "Test 3b: lint-packs pass H" "lint failed"
  log_result "[phase7] lint-packs output (last 20 lines):"
  log_result "$(echo "$lint_out" | tail -20)"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 6: Blueprint disclaimer
# ─────────────────────────────────────────────────────────────────────
info "Test 6: Blueprint disclaimer"

disclaimer="Not real CKA exam content; independently authored"
if grep -qF "$disclaimer" "$REPO_ROOT/exams/blueprint-alpha/README.md" 2>/dev/null; then
  pass "Test 6a: README contains disclaimer"
else
  fail "Test 6a: README disclaimer" "string not found"
fi
if grep -qF "$disclaimer" "$REPO_ROOT/exams/blueprint-alpha/manifest.yaml" 2>/dev/null; then
  pass "Test 6b: manifest contains disclaimer"
else
  fail "Test 6b: manifest disclaimer" "string not found"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 4: Score report generation (end-to-end exam run)
# ─────────────────────────────────────────────────────────────────────
info "Test 4: Score report (end-to-end with real graders)"
info "  Running exam — auto-advancing all 17 questions + submit..."

# Feed 17 Enter keystrokes (advance) + "y" (submit)
input=""
for i in $(seq 1 17); do input+=$'\n'; done
input+="y"

exam_out=$(printf '%s' "$input" | timeout 600 bash "$CKA_SIM" exam blueprint-alpha 2>&1) || true

# Find session timestamp
session_ts=$(echo "$exam_out" | grep -oE 'Session: [0-9T]+Z' | grep -oE '[0-9T]+Z' | head -1 || true)
if [[ -z "$session_ts" ]]; then
  session_ts=$(ls -t ~/.cka-sim/sessions/*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.json//' || true)
fi

if [[ -n "$session_ts" ]]; then
  report_file="$HOME/.cka-sim/sessions/${session_ts}.md"
  json_file="$HOME/.cka-sim/sessions/${session_ts}.json"

  if [[ -f "$report_file" ]]; then
    pass "Test 4a: report file created at $report_file"
  else
    fail "Test 4a: report file" "not found at $report_file"
  fi

  if [[ -f "$json_file" ]]; then
    has_domain=$(grep -c "Per-Domain Breakdown" "$report_file" 2>/dev/null || echo 0)
    has_traps=$(grep -c "Top 5 Traps Hit" "$report_file" 2>/dev/null || echo 0)
    has_drills=$(grep -c "Suggested Next Drills" "$report_file" 2>/dev/null || echo 0)
    has_total=$(grep -cE "Total Score: [0-9]+/100" "$report_file" 2>/dev/null || echo 0)

    if (( has_domain > 0 && has_traps > 0 && has_drills > 0 && has_total > 0 )); then
      pass "Test 4b: report contains all required sections"
    else
      fail "Test 4b: report sections" "domain=$has_domain traps=$has_traps drills=$has_drills total=$has_total"
    fi

    if grep -qE "(PASS|FAIL) vs 66% pass mark" "$report_file" 2>/dev/null; then
      pass "Test 4c: report has pass/fail verdict vs 66%"
    else
      fail "Test 4c: pass/fail verdict" "not found in report"
    fi

    # Log the actual report content
    log_result "[phase7] Report content:"
    cat "$report_file" >> "$RESULTS_FILE"
  else
    fail "Test 4b: session JSON" "not found at $json_file"
    fail "Test 4c: pass/fail verdict" "skipped (no JSON)"
  fi
else
  fail "Test 4a: exam session" "no session timestamp found"
  fail "Test 4b: report sections" "skipped"
  fail "Test 4c: pass/fail verdict" "skipped"
  log_result "[phase7] exam output (first 40 lines):"
  log_result "$(echo "$exam_out" | head -40)"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 5: Score + list commands
# ─────────────────────────────────────────────────────────────────────
info "Test 5: Score + list commands"

if [[ -n "$session_ts" ]]; then
  score_out=$(bash "$CKA_SIM" score "$session_ts" 2>&1) || true
  if echo "$score_out" | grep -q "Per-Domain Breakdown"; then
    pass "Test 5a: cka-sim score <ts> displays report"
  else
    fail "Test 5a: cka-sim score" "output missing report sections"
  fi
else
  fail "Test 5a: cka-sim score" "skipped (no session)"
fi

list_out=$(bash "$CKA_SIM" list history 2>&1) || true
if echo "$list_out" | grep -qE "(blueprint-alpha|Started|No exam history)"; then
  pass "Test 5b: cka-sim list history runs"
else
  fail "Test 5b: cka-sim list history" "unexpected output"
fi
log_result "[phase7] list history output:"
log_result "$list_out"

# ─────────────────────────────────────────────────────────────────────
# Test 1 & 2: Timer + Signals (interactive — instructions only)
# ─────────────────────────────────────────────────────────────────────
info "Test 1 & 2: Timer + Signals (interactive — run manually)"
log_result "[phase7] Test 1+2: SKIPPED (interactive — requires manual Ctrl-C/Ctrl-Z verification)"
log_result "[phase7]   To verify: bash $CKA_SIM exam blueprint-alpha"
log_result "[phase7]   1. Timer at bottom updates every second"
log_result "[phase7]   2. Ctrl-C flags question (does NOT kill)"
log_result "[phase7]   3. Ctrl-Z pauses; fg resumes with correct time"

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────
printf '\n'
header "Phase 7 UAT Results"
printf 'Total: %d  Passed: %d  Failed: %d  Skipped (interactive): 2\n' "$total" "$passed" "$failed"
log_result ""
log_result "[phase7] SUMMARY: Total=$total Passed=$passed Failed=$failed Skipped=2(interactive)"

if (( failed == 0 )); then
  ok "All automated Phase 7 UAT tests passed!"
  exit 0
else
  err "$failed test(s) failed. Review output above."
  exit 1
fi
