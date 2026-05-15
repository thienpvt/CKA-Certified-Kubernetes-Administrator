#!/bin/bash
# Phase 07.1 AUDIT-01 — distinguish setup-state from candidate work.
# cluster-architecture/01-rbac-viewer/grade.sh
#
# Ownership analysis:
#   - Role pod-viewer / RoleBinding viewer-binding / SA viewer: all authored by
#     setup.sh (broken state: Role has only "watch" verb). Pre-07.1 grader gave
#     credit for assert_resource_exists on all three → setup-state leakage.
#   - Candidate work: PATCH the existing Role to add get+list verbs (see
#     ref-solution.sh). Generation-bumping edit → assert_changed_since_setup.
#   - can-i assertion is the authoritative behavioural check (yes ⇔ candidate fixed
#     the verbs) and remains in scoring.
#   - Trap detector continues to fire on the original broken-verbs content.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Setup-state assertions (weight=0) — kept for diagnostics; do NOT score.
# Pre-07.1 these counted toward the score; Phase 07.1 demotes to weight=0 so
# empty submission cannot harvest credit from setup-authored resources.
cka_sim::grade::assert_resource_exists rolebinding viewer-binding -n "$CKA_SIM_LAB_NS" 0
cka_sim::grade::assert_resource_exists serviceaccount viewer -n "$CKA_SIM_LAB_NS" 0

# Candidate-work assertion 1: Role pod-viewer must have been modified since
# baseline capture (candidate added get+list verbs). Setup-authored, so it
# is in the baseline; candidate's patch bumps generation/rv.
cka_sim::grade::assert_changed_since_setup role pod-viewer -n "$CKA_SIM_LAB_NS" 1

# Candidate-work assertion 2: SA can actually get pods (behavioural proof).
cka_sim::grade::assert_can_i get pods \
  --as "system:serviceaccount:${CKA_SIM_LAB_NS}:viewer" \
  -n "$CKA_SIM_LAB_NS" 1

# Trap detector — fires while Role still carries the broken verb list.
tid=$(cka_sim::trap::detect_rbac_viewer_role_mismatch "$CKA_SIM_LAB_NS" "pod-viewer")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

cka_sim::grade::emit_result
