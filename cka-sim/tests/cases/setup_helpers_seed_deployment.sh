#!/bin/bash
# setup_helpers_seed_deployment.sh — verifies Deployment YAML shape across flag permutations.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

kubectl() { if [[ "${1:-}" == "apply" ]]; then cat; else return 64; fi; }
export -f kubectl

# shellcheck source=../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# --- Case A: minimal (no flags) ---
out_a=$(cka_sim::setup::seed_deployment "cka-sim-x" "q-load" "nginx:1.27")
expect_contains "$out_a" "kind: Deployment"       "minimal: kind is Deployment"          || case_failed=1
expect_contains "$out_a" "name: q-load"           "minimal: name embedded"               || case_failed=1
expect_contains "$out_a" "namespace: cka-sim-x"   "minimal: namespace embedded"          || case_failed=1
expect_contains "$out_a" "replicas: 1"            "minimal: default replicas=1"          || case_failed=1
expect_contains "$out_a" "image: nginx:1.27"      "minimal: image embedded"              || case_failed=1
if [[ "$out_a" == *"serviceAccountName:"* ]]; then
  expect_eq "has-sa" "no-sa" "minimal: no serviceAccountName line when --sa not passed" || case_failed=1
else
  expect_eq "no-sa" "no-sa" "minimal: serviceAccountName absent" || case_failed=1
fi
if [[ "$out_a" == *"resources:"* ]]; then
  expect_eq "has-res" "no-res" "minimal: no resources block when --cpu/--memory not passed" || case_failed=1
else
  expect_eq "no-res" "no-res" "minimal: resources block absent" || case_failed=1
fi

# --- Case B: with --sa --cpu --memory ---
out_b=$(cka_sim::setup::seed_deployment "cka-sim-x" "q-load" "nginx:1.27" --sa load-app-sa --cpu 50m --memory 64Mi)
expect_contains "$out_b" "serviceAccountName: load-app-sa" "with-sa: serviceAccountName embedded" || case_failed=1
expect_contains "$out_b" "cpu: 50m"                        "with-sa: cpu request embedded"        || case_failed=1
expect_contains "$out_b" "memory: 64Mi"                    "with-sa: memory request embedded"     || case_failed=1

# --- Case C: with --replicas 3 ---
out_c=$(cka_sim::setup::seed_deployment "cka-sim-x" "q-load" "nginx:1.27" --replicas 3)
expect_contains "$out_c" "replicas: 3" "with-replicas: replicas=3" || case_failed=1

exit "$case_failed"
