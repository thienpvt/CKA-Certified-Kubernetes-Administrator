#!/bin/bash
# setup_helpers_wait_for_ns_active.sh — verifies wait_for_ns_active's phase-sequence semantics.
#
# Subshell-persistence note: wait_for_ns_active calls `phase=$(kubectl get ns ...)`, which
# spawns a subshell — any counter variable incremented inside that subshell is lost when
# the subshell exits. We therefore back all per-invocation state with tempfiles whose paths
# are exported into the subshell via `export -f`. The tempfile content (not any shell var)
# is the source of truth.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# --- Test 1: structural — helper exists and is sourceable ---
# shellcheck source=../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"
if declare -F cka_sim::setup::wait_for_ns_active >/dev/null; then
  expect_eq "exists" "exists" "wait_for_ns_active function defined after sourcing lib/setup.sh" || case_failed=1
else
  expect_eq "missing" "exists" "wait_for_ns_active function defined after sourcing lib/setup.sh" || case_failed=1
fi

# --- Test 2: argument validation — `die` on missing ns ---
# Run in a subshell so `die`'s exit doesn't kill the case file.
rc=0
( cka_sim::setup::wait_for_ns_active >/dev/null 2>&1 ) || rc=$?
expect_eq "$rc" "1" "wait_for_ns_active exits non-zero when ns arg is missing (set -u catches unbound)" || case_failed=1

# --- Test 3: phase-sequence — file-backed counter survives subshells ---
# Simulate Phase 3 race: first `get` returns empty (triggers re-apply), second returns Active.
# Counter file lives on disk so the subshell spawned by `$(kubectl get ...)` can increment it
# via `echo N > $file`, and the parent shell sees the update via the next read.
GET_COUNTER=$(mktemp)
APPLY_COUNTER=$(mktemp)
echo 0 > "$GET_COUNTER"
echo 0 > "$APPLY_COUNTER"
export GET_COUNTER APPLY_COUNTER

kubectl() {
  case "${1:-}" in
    get)
      local n
      n=$(cat "$GET_COUNTER")
      n=$(( n + 1 ))
      echo "$n" > "$GET_COUNTER"
      # First call -> empty (simulate ns missing / Terminating race); subsequent -> Active.
      if (( n == 1 )); then
        printf ''
      else
        printf 'Active'
      fi
      ;;
    apply)
      local n
      n=$(cat "$APPLY_COUNTER")
      n=$(( n + 1 ))
      echo "$n" > "$APPLY_COUNTER"
      cat >/dev/null   # swallow heredoc
      ;;
    *)
      return 64
      ;;
  esac
}
export -f kubectl

# Shorten sleep to instant for test speed (helper uses `sleep 5`).
sleep() { :; }
export -f sleep

# Call with timeout=10 -> iterations = 2 (10/5). First iter: empty -> re-apply; second: Active -> return 0.
if ! cka_sim::setup::wait_for_ns_active "cka-sim-storage-01" "storage" "storage-pvc-binding" 10 >/dev/null 2>&1; then
  case_failed=1
fi

get_count=$(cat "$GET_COUNTER")
apply_count=$(cat "$APPLY_COUNTER")

expect_eq "$get_count"   "2" "kubectl get called exactly twice (first empty, second Active)" || case_failed=1
expect_eq "$apply_count" "1" "re-apply fired exactly once on empty phase"                     || case_failed=1

rm -f "$GET_COUNTER" "$APPLY_COUNTER"

exit "$case_failed"
