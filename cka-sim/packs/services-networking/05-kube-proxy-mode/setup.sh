#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" services-networking services-kube-proxy-mode
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" services-networking services-kube-proxy-mode 120

# Create sandbox directory with sentinel guard
mkdir -p /tmp/q05-kube-proxy
touch /tmp/q05-kube-proxy/.cka-sim-sentinel

# Phase 10 BUG-H02: seed an out-of-enum placeholder. The previous value 'ipvs'
# collided with the live mode on ipvs clusters, breaking the candidate-wrote
# check (grade.sh:23) and gating Assertions 2 and 3 to fail. 'placeholder' is
# outside {iptables, ipvs, nftables}, so reported != seeded for every valid
# candidate write on every cluster.
SEED_MODE='placeholder'
echo "$SEED_MODE" > /tmp/q05-kube-proxy/reported-mode.txt
chmod 0644 /tmp/q05-kube-proxy/reported-mode.txt

# Phase 07.1 AUDIT-01: persist the seeded value to a sentinel so grade.sh can
# detect "candidate has not written" (empty-submission honesty).
echo "$SEED_MODE" > /tmp/q05-kube-proxy/.setup-seeded-mode
chmod 0444 /tmp/q05-kube-proxy/.setup-seeded-mode
