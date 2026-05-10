#!/bin/bash
# storage/06-pvc-mount-pod/grade.sh — asserts Deployment q06-reader exists,
# mounts PVC q06-data read-only, and the pod can read /data/marker via exec.
# Also records default-sa-used trap if the candidate's pod uses the default SA.
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=../../../lib/grade.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/grade.sh"
# shellcheck source=../../../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Wait for the candidate's Deployment to become Available before asserting.
kubectl wait --for=condition=Available deployment/q06-reader \
  -n "$CKA_SIM_LAB_NS" --timeout=90s 2>/dev/null || true

# Assertion 1: Deployment exists.
cka_sim::grade::assert_resource_exists deployment q06-reader -n "$CKA_SIM_LAB_NS"

# Assertion 2: the Deployment's pod template references the PVC q06-data.
cka_sim::grade::assert_field_eq deployment q06-reader \
  '{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' \
  'q06-data' -n "$CKA_SIM_LAB_NS"

# Assertion 3: the container volumeMount is read-only.
cka_sim::grade::assert_field_eq deployment q06-reader \
  '{.spec.template.spec.containers[0].volumeMounts[0].readOnly}' \
  'true' -n "$CKA_SIM_LAB_NS"

# Assertion 4 (behavioural): exec into the pod and cat /data/marker. The file
# was pre-written by the setup writer pod; if the mount is wrong or the PVC is
# not bound, exec returns empty and this assertion fails.
CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
marker=$(kubectl exec -n "$CKA_SIM_LAB_NS" deployment/q06-reader -- cat /data/marker 2>/dev/null | tr -d '\n\r ' || true)
if [[ "$marker" == "q06-marker" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  CKA_SIM_GRADE_PASSES+=("exec probe: deploy/q06-reader /data/marker == 'q06-marker'")
  ok "exec probe: deploy/q06-reader /data/marker == 'q06-marker'"
else
  CKA_SIM_GRADE_FAILS+=("exec probe: deploy/q06-reader /data/marker = '$marker' (expected 'q06-marker')")
  err "exec probe: deploy/q06-reader /data/marker = '$marker' (expected 'q06-marker')"
fi

# Trap detector: pick a live pod under the Deployment and check its SA.
pod=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=q06-reader \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$pod" ]]; then
  tid=$(cka_sim::trap::detect_default_sa_used "$CKA_SIM_LAB_NS" "$pod")
  [[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
fi

cka_sim::grade::emit_result
