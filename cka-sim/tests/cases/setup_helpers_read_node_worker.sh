#!/bin/bash
# setup_helpers_read_node_worker.sh — verifies read_node_worker echoes the first
# non-control-plane node name and fails loudly when no worker is present.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# --- Test 1: happy path — kubectl echoes a worker name, helper re-emits it ---
kubectl() {
  # Assert the helper asked with the non-control-plane selector.
  local argv="$*"
  if [[ "$argv" == *"-l !node-role.kubernetes.io/control-plane"* ]]; then
    printf 'worker-1'
    return 0
  fi
  return 64
}
export -f kubectl

# shellcheck source=../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

out=$(cka_sim::setup::read_node_worker 2>/dev/null)
expect_eq "$out" "worker-1" "read_node_worker echoes the worker node name" || case_failed=1

# --- Test 2: empty path — helper dies, exit non-zero, error mentions worker discovery ---
kubectl() { printf ''; return 0; }
export -f kubectl

# Run in a subshell so `die`'s exit 1 does not kill this case file.
rc=0
err_out=$( ( cka_sim::setup::read_node_worker ) 2>&1 >/dev/null ) || rc=$?
expect_eq "$rc" "1" "read_node_worker exits 1 when no worker is discoverable" || case_failed=1
expect_match "$err_out" "no non-control-plane worker node found" "read_node_worker surfaces specific error message" || case_failed=1

exit "$case_failed"
