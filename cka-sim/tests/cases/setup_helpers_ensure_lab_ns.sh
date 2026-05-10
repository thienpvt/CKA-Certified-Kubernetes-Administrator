#!/bin/bash
# setup_helpers_ensure_lab_ns.sh — verifies ensure_lab_ns emits Namespace YAML with cka-sim labels.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# Stub kubectl: on `apply` cat stdin to capture the heredoc YAML.
kubectl() { if [[ "${1:-}" == "apply" ]]; then cat; else return 64; fi; }
export -f kubectl

# shellcheck source=../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

out=$(cka_sim::setup::ensure_lab_ns "cka-sim-storage-01" "storage" "storage-pvc-binding")
expect_contains "$out" "name: cka-sim-storage-01"           "namespace name embedded"      || case_failed=1
expect_contains "$out" "cka-sim/pack: storage"              "pack label set"               || case_failed=1
expect_contains "$out" "cka-sim/question-id: storage-pvc-binding" "question-id label set"  || case_failed=1
expect_contains "$out" "kind: Namespace"                    "kind is Namespace"            || case_failed=1

exit "$case_failed"
