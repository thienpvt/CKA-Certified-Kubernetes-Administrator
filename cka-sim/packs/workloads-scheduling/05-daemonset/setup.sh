#!/bin/bash
# workloads-scheduling/05-daemonset/setup.sh — candidate authors the DaemonSet from scratch.
# Setup only prepares the lab namespace; no pre-seeded workload (the DaemonSet itself is the task).
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set (drill runner exports it)}"

# shellcheck source=../../../lib/setup.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/setup.sh"

# Idempotent ns create + 120s Active wait.
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" workloads-scheduling workloads-daemonset
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-daemonset 120

# No DaemonSet pre-seed — candidate authors it from scratch (per RESEARCH §2.2 Q05).
