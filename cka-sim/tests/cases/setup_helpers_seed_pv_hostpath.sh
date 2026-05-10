#!/bin/bash
# setup_helpers_seed_pv_hostpath.sh — verifies PV YAML shape for both affinity paths.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# Stub kubectl: cat stdin on apply so the emitted heredoc surfaces as stdout.
kubectl() { if [[ "${1:-}" == "apply" ]]; then cat; else return 64; fi; }
export -f kubectl

# shellcheck source=../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# --- Shape A: WITHOUT affinity (6th arg empty -> trap-seeding) ---
out_a=$(cka_sim::setup::seed_pv_hostpath "q-test-pv" "1Gi" "ReadWriteOnce" "Retain" "/tmp/q-test-pv" "")
expect_contains "$out_a" "kind: PersistentVolume"      "without-affinity: kind is PV"              || case_failed=1
expect_contains "$out_a" "name: q-test-pv"             "without-affinity: name embedded"           || case_failed=1
expect_contains "$out_a" "path: /tmp/q-test-pv"        "without-affinity: hostPath.path embedded"  || case_failed=1
expect_contains "$out_a" "storage: 1Gi"                "without-affinity: capacity embedded"       || case_failed=1
if [[ "$out_a" == *"nodeAffinity:"* ]]; then
  expect_eq "has-affinity" "no-affinity" "without-affinity: nodeAffinity block must be ABSENT" || case_failed=1
else
  expect_eq "no-affinity" "no-affinity" "without-affinity: nodeAffinity block absent" || case_failed=1
fi

# --- Shape B: WITH affinity (kubernetes.io/hostname) ---
out_b=$(cka_sim::setup::seed_pv_hostpath "q-test-pv" "1Gi" "ReadWriteOnce" "Retain" "/tmp/q-test-pv" "kubernetes.io/hostname")
expect_contains "$out_b" "nodeAffinity:"                       "with-affinity: nodeAffinity block present" || case_failed=1
expect_contains "$out_b" "key: kubernetes.io/hostname"         "with-affinity: key is hostname"            || case_failed=1
expect_contains "$out_b" "operator: Exists"                    "with-affinity: operator is Exists"         || case_failed=1

exit "$case_failed"
