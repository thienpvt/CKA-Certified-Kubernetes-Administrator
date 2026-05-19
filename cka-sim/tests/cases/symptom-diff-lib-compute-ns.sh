#!/bin/bash
# tests/cases/symptom-diff-lib-compute-ns.sh — Phase 16 BASELINE-01
# Locks: cka_sim::symptom_diff::compute_ns produces RFC 1123 namespaces
# under 64 chars, with no trailing dash, for the three sentinel inputs.
set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

# shellcheck disable=SC1091
source "$CKA_SIM_ROOT/lib/symptom-diff.sh"

assert_ns() {
  local prefix="$1" pack="$2" q="$3" expected="$4" got
  got=$(cka_sim::symptom_diff::compute_ns "$prefix" "$pack" "$q")
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: compute_ns(%s,%s,%s)\n  expected=%q\n       got=%q\n' \
      "$prefix" "$pack" "$q" "$expected" "$got" >&2
    exit 1
  fi
  # RFC 1123 invariants on every output.
  if (( ${#got} > 63 )); then
    printf 'FAIL: ns length %d > 63 (input %s/%s/%s)\n' "${#got}" "$prefix" "$pack" "$q" >&2
    exit 1
  fi
  if [[ "${got: -1}" == "-" ]]; then
    printf 'FAIL: ns has trailing dash (%q)\n' "$got" >&2
    exit 1
  fi
  if ! [[ "$got" =~ ^[a-z0-9-]+$ ]]; then
    printf 'FAIL: ns contains non-RFC1123 chars (%q)\n' "$got" >&2
    exit 1
  fi
}

# Case 1: prefix='audit', short pack/q → no truncation, no munging.
assert_ns audit storage 01-pvc-binding 'cka-sim-audit-storage-01-pvc-binding'

# Case 2: prefix='lint', long pack/q → truncates to 63 chars (verified runtime output).
# Raw: cka-sim-lint-workloads-scheduling-08-nodeselector-affinity-taints (65 chars)
# Truncated to 63: cka-sim-lint-workloads-scheduling-08-nodeselector-affinity-tain
assert_ns lint workloads-scheduling 08-nodeselector-affinity-taints \
          'cka-sim-lint-workloads-scheduling-08-nodeselector-affinity-tain'

# Case 3: prefix='audit', cluster-architecture/08-priorityclass → fits, contains literal segments.
assert_ns audit cluster-architecture 08-priorityclass \
          'cka-sim-audit-cluster-architecture-08-priorityclass'

exit 0
