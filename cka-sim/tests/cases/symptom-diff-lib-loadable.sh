#!/bin/bash
# tests/cases/symptom-diff-lib-loadable.sh — Phase 16 BASELINE-01
# Locks: lib/symptom-diff.sh is sourceable, the module guard prevents
# double-source breakage, and the four expected functions are declared.
set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

# 1) First source must succeed and set the guard.
# shellcheck disable=SC1091
source "$CKA_SIM_ROOT/lib/symptom-diff.sh"
if [[ "${CKA_SIM_SYMPTOM_DIFF_SOURCED:-}" != "1" ]]; then
  printf 'FAIL: CKA_SIM_SYMPTOM_DIFF_SOURCED not set after first source\n' >&2
  exit 1
fi

# 2) Second source must be a no-op (the readonly guard would otherwise re-set
# a readonly variable and fail). Run in a subshell so a failure is captured
# rather than aborting the case.
if ! ( source "$CKA_SIM_ROOT/lib/symptom-diff.sh" ); then
  printf 'FAIL: second source of symptom-diff.sh failed (module guard broken)\n' >&2
  exit 1
fi

# 3) The 21 KIND_ALIAS entries are populated.
expected_kinds=(pvc pv pod svc deploy networkpolicy configmap secret namespace
                role rolebinding clusterrole clusterrolebinding serviceaccount
                hpa daemonset replicaset priorityclass storageclass volumesnapshot
                volumesnapshotclass ingress)
for k in "${expected_kinds[@]}"; do
  if [[ -z "${KIND_ALIAS[$k]:-}" ]]; then
    printf 'FAIL: KIND_ALIAS missing entry for %s\n' "$k" >&2
    exit 1
  fi
done

# 4) The four functions are declared.
for fn in _jsonpath_to_jq _is_cluster_scoped \
          cka_sim::symptom_diff::compute_ns cka_sim::symptom_diff::run_one; do
  if ! declare -F "$fn" >/dev/null 2>&1; then
    printf 'FAIL: function not declared: %s\n' "$fn" >&2
    exit 1
  fi
done

exit 0
