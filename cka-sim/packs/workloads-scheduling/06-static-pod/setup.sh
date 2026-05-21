#!/bin/bash
# workloads-scheduling/06-static-pod/setup.sh
# cka-sim-lint: allow-node-literal  # drill is hostname-bound to the kubeadm CP node; dynamic discovery retrofit tracked in deferred-items
# SSH preflight only. The question is about node-01 static pods, so setup does
# NOT mutate /etc/kubernetes/manifests — that is the candidate's job.
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# SSH preflight per RESEARCH §9 Q06: fail loudly if BOOT-02/03 have regressed.
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 node-01 true 2>/dev/null; then
  echo "error: passwordless SSH to node-01 failed -- run 'cka-sim doctor' and re-run 'cka-sim bootstrap' if needed" >&2
  exit 1
fi

# Idempotent ns create + 120s Active wait (still created so reset.sh has a ns to delete).
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-static-pod
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-static-pod 120

# No in-cluster pre-seed; candidate drops the manifest into /etc/kubernetes/manifests on node-01.
