#!/bin/bash
# cluster-architecture/01-rbac-viewer/grade.sh
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertions
cka_sim::grade::assert_resource_exists role pod-viewer -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_resource_exists rolebinding viewer-binding -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_resource_exists serviceaccount viewer -n "$CKA_SIM_LAB_NS"

# Core: can the viewer SA actually get pods? yes == fix applied, no == trap still present.
cka_sim::grade::assert_can_i get pods \
  --as "system:serviceaccount:${CKA_SIM_LAB_NS}:viewer" \
  -n "$CKA_SIM_LAB_NS"

# Trap detector: Role binds pods but lacks get/list verbs.
tid=$(cka_sim::trap::detect_rbac_viewer_role_mismatch "$CKA_SIM_LAB_NS" "pod-viewer")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

cka_sim::grade::emit_result
