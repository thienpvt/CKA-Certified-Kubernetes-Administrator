#!/bin/bash
# Phase 4 UAT — run remaining live-drill tests on the cluster.
# Usage: bash cka-sim/tests/phase4-uat.sh
#
# Prerequisites:
#   - On the control-plane node
#   - Cluster healthy (cka-sim doctor passes)
#   - SSH to workers works

set -uo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT
CKA_SIM="$CKA_SIM_ROOT/bin/cka-sim"

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"

header "Phase 4 UAT — Storage + Workloads-Scheduling Live Drills"

total=0
passed=0
failed=0

pass() { passed=$((passed+1)); total=$((total+1)); ok "PASS: $1"; }
fail() { failed=$((failed+1)); total=$((total+1)); err "FAIL: $1 — $2"; }

# ─────────────────────────────────────────────────────────────────────
# Test 6: Live Drill — Storage Pack (all questions)
# ─────────────────────────────────────────────────────────────────────
info "Test 6: Live Drill — Storage Pack"

storage_count=$(grep -c 'path:' "$CKA_SIM_ROOT/packs/storage/manifest.yaml" 2>/dev/null || echo 0)
storage_pass=0
storage_fail=0

for (( q=1; q<=storage_count; q++ )); do
  info "  Drilling storage Q$q/$storage_count..."
  # Run drill with "done" input to trigger grading after setup
  drill_out=$(printf 'done\n' | timeout 120 bash "$CKA_SIM" drill storage "$q" 2>&1) || true
  drill_rc=$?

  if echo "$drill_out" | grep -q 'SCORE:'; then
    storage_pass=$((storage_pass+1))
    ok "  Q$q: graded (rc=$drill_rc)"
  else
    storage_fail=$((storage_fail+1))
    err "  Q$q: no SCORE output (rc=$drill_rc)"
    echo "$drill_out" | tail -5 >&2
  fi
done

if (( storage_fail == 0 && storage_count > 0 )); then
  pass "Test 6: Storage pack — all $storage_count questions drill successfully"
else
  fail "Test 6: Storage pack" "$storage_fail/$storage_count questions failed"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 7: Live Drill — Workloads-Scheduling Pack (all questions)
# ─────────────────────────────────────────────────────────────────────
info "Test 7: Live Drill — Workloads-Scheduling Pack"

ws_count=$(grep -c 'path:' "$CKA_SIM_ROOT/packs/workloads-scheduling/manifest.yaml" 2>/dev/null || echo 0)
ws_pass=0
ws_fail=0

for (( q=1; q<=ws_count; q++ )); do
  info "  Drilling workloads-scheduling Q$q/$ws_count..."
  drill_out=$(printf 'done\n' | timeout 120 bash "$CKA_SIM" drill workloads-scheduling "$q" 2>&1) || true
  drill_rc=$?

  if echo "$drill_out" | grep -q 'SCORE:'; then
    ws_pass=$((ws_pass+1))
    ok "  Q$q: graded (rc=$drill_rc)"
  else
    ws_fail=$((ws_fail+1))
    err "  Q$q: no SCORE output (rc=$drill_rc)"
    echo "$drill_out" | tail -5 >&2
  fi
done

if (( ws_fail == 0 && ws_count > 0 )); then
  pass "Test 7: Workloads-Scheduling pack — all $ws_count questions drill successfully"
else
  fail "Test 7: Workloads-Scheduling pack" "$ws_fail/$ws_count questions failed"
fi

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────
printf '\n'
header "Phase 4 UAT Results"
printf 'Total: %d  Passed: %d  Failed: %d\n' "$total" "$passed" "$failed"
printf 'Storage: %d/%d  Workloads: %d/%d\n' "$storage_pass" "$storage_count" "$ws_pass" "$ws_count"

if (( failed == 0 )); then
  ok "All Phase 4 live-drill UAT tests passed!"
  exit 0
else
  err "$failed test(s) failed."
  exit 1
fi
