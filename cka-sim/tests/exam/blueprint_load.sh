#!/bin/bash
# cka-sim/tests/exam/blueprint_load.sh — verify blueprint manifest parsing.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# Point CKA_SIM_ROOT at fixtures so packs/mock-pack-alpha/ resolves
REAL_ROOT="$CKA_SIM_ROOT"
export CKA_SIM_ROOT="$REAL_ROOT/tests/fixtures/exam"

source "$REAL_ROOT/lib/exam-blueprint.sh"

MANIFEST="$CKA_SIM_ROOT/blueprint-mock-alpha.yaml"

# --- Test 1: load parses 17 questions ---
cka_sim::blueprint::load "$MANIFEST"

count=${#CKA_SIM_BLUEPRINT_PACKS[@]}
if [[ "$count" -ne 17 ]]; then
  err "Test 1: expected 17 questions, got $count"
  case_failed=1
else
  ok "Test 1: load parsed 17 questions"
fi

# --- Test 2: META fields populated ---
if [[ "${CKA_SIM_BLUEPRINT_META[id]:-}" != "mock-alpha" ]]; then
  err "Test 2: expected id 'mock-alpha', got '${CKA_SIM_BLUEPRINT_META[id]:-}'"
  case_failed=1
else
  ok "Test 2: META[id] = mock-alpha"
fi

if [[ "${CKA_SIM_BLUEPRINT_META[durationMinutes]:-}" != "120" ]]; then
  err "Test 2b: expected durationMinutes '120', got '${CKA_SIM_BLUEPRINT_META[durationMinutes]:-}'"
  case_failed=1
else
  ok "Test 2b: META[durationMinutes] = 120"
fi

# --- Test 3: weighting parsed ---
if [[ "${CKA_SIM_BLUEPRINT_META[weight_storage]:-}" != "10" ]]; then
  err "Test 3: expected weight_storage=10, got '${CKA_SIM_BLUEPRINT_META[weight_storage]:-}'"
  case_failed=1
else
  ok "Test 3: weighting parsed correctly"
fi

# --- Test 4: estimated_minutes_sum ---
sum=$(cka_sim::blueprint::estimated_minutes_sum)
if (( sum < 100 || sum > 200 )); then
  err "Test 4: estimated_minutes_sum=$sum seems wrong (expected ~125)"
  case_failed=1
else
  ok "Test 4: estimated_minutes_sum=$sum (reasonable)"
fi

# --- Test 5: all packs are mock-pack-alpha ---
all_mock=1
for p in "${CKA_SIM_BLUEPRINT_PACKS[@]}"; do
  if [[ "$p" != "mock-pack-alpha" ]]; then
    all_mock=0; break
  fi
done
if [[ "$all_mock" -ne 1 ]]; then
  err "Test 5: not all packs are mock-pack-alpha"
  case_failed=1
else
  ok "Test 5: all packs are mock-pack-alpha"
fi

export CKA_SIM_ROOT="$REAL_ROOT"
exit "$case_failed"
