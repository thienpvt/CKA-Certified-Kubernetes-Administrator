#!/bin/bash
# setup_helpers_seed_netpol_skeleton.sh — verifies seed_netpol_skeleton emits a
# NetworkPolicy skeleton with podSelector, policyTypes, and a DNS-allow egress rule
# targeting the kube-system namespace on UDP/TCP port 53.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# Stub kubectl: on `apply` cat stdin so the helper's heredoc surfaces on stdout.
kubectl() { if [[ "${1:-}" == "apply" ]]; then cat; else return 64; fi; }
export -f kubectl

# shellcheck source=../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

out=$(cka_sim::setup::seed_netpol_skeleton "cka-sim-services-networking-06" "dns-allow" "app=probe")

expect_contains "$out" "kind: NetworkPolicy"                                       "kind is NetworkPolicy"                  || case_failed=1
expect_contains "$out" "name: dns-allow"                                           "name embedded"                          || case_failed=1
expect_contains "$out" "namespace: cka-sim-services-networking-06"                 "namespace embedded"                     || case_failed=1
expect_contains "$out" "app: probe"                                                "podSelector label embedded"             || case_failed=1
expect_contains "$out" "policyTypes:"                                              "policyTypes block present"              || case_failed=1
expect_contains "$out" "- Ingress"                                                 "Ingress policyType present"             || case_failed=1
expect_contains "$out" "- Egress"                                                  "Egress policyType present"              || case_failed=1
expect_contains "$out" "kubernetes.io/metadata.name: kube-system"                  "DNS egress targets kube-system ns"      || case_failed=1
expect_contains "$out" "protocol: UDP"                                             "UDP protocol present"                   || case_failed=1
expect_contains "$out" "protocol: TCP"                                             "TCP protocol present"                   || case_failed=1

# Port 53 must appear at least twice (once per protocol).
port53_count=$(printf '%s\n' "$out" | grep -cE '^\s*port:\s*53\s*$' || true)
expect_eq "$port53_count" "2" "port: 53 appears twice (UDP + TCP)" || case_failed=1

exit "$case_failed"
