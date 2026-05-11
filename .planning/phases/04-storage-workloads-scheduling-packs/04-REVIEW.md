---
phase: 04-storage-workloads-scheduling-packs
reviewed: 2026-05-11T00:03:00Z
depth: standard
files_reviewed: 63
files_reviewed_list:
  - .github/workflows/validate.yml
  - cka-sim/lib/setup.sh
  - cka-sim/packs/storage/01-pvc-binding/setup.sh
  - cka-sim/packs/storage/02-storageclass-dynamic/grade.sh
  - cka-sim/packs/storage/02-storageclass-dynamic/metadata.yaml
  - cka-sim/packs/storage/02-storageclass-dynamic/question.md
  - cka-sim/packs/storage/02-storageclass-dynamic/ref-solution.sh
  - cka-sim/packs/storage/02-storageclass-dynamic/reset.sh
  - cka-sim/packs/storage/02-storageclass-dynamic/setup.sh
  - cka-sim/packs/storage/03-access-modes-reclaim/grade.sh
  - cka-sim/packs/storage/03-access-modes-reclaim/metadata.yaml
  - cka-sim/packs/storage/03-access-modes-reclaim/question.md
  - cka-sim/packs/storage/03-access-modes-reclaim/ref-solution.sh
  - cka-sim/packs/storage/03-access-modes-reclaim/reset.sh
  - cka-sim/packs/storage/03-access-modes-reclaim/setup.sh
  - cka-sim/packs/storage/04-csi-volumesnapshot/grade.sh
  - cka-sim/packs/storage/04-csi-volumesnapshot/metadata.yaml
  - cka-sim/packs/storage/04-csi-volumesnapshot/question.md
  - cka-sim/packs/storage/04-csi-volumesnapshot/ref-solution.sh
  - cka-sim/packs/storage/04-csi-volumesnapshot/reset.sh
  - cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh
  - cka-sim/packs/storage/05-wait-for-first-consumer/grade.sh
  - cka-sim/packs/storage/05-wait-for-first-consumer/metadata.yaml
  - cka-sim/packs/storage/05-wait-for-first-consumer/question.md
  - cka-sim/packs/storage/05-wait-for-first-consumer/ref-solution.sh
  - cka-sim/packs/storage/05-wait-for-first-consumer/reset.sh
  - cka-sim/packs/storage/05-wait-for-first-consumer/setup.sh
  - cka-sim/packs/storage/06-pvc-mount-pod/grade.sh
  - cka-sim/packs/storage/06-pvc-mount-pod/metadata.yaml
  - cka-sim/packs/storage/06-pvc-mount-pod/ref-solution.sh
  - cka-sim/packs/storage/06-pvc-mount-pod/reset.sh
  - cka-sim/packs/storage/06-pvc-mount-pod/setup.sh
  - cka-sim/packs/storage/coverage.yaml
  - cka-sim/packs/storage/manifest.yaml
  - cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh
  - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/grade.sh
  - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/metadata.yaml
  - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/ref-solution.sh
  - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/reset.sh
  - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/setup.sh
  - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/grade.sh
  - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/metadata.yaml
  - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/question.md
  - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/ref-solution.sh
  - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/reset.sh
  - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/setup.sh
  - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/grade.sh
  - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/metadata.yaml
  - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/ref-solution.sh
  - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/reset.sh
  - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/setup.sh
  - cka-sim/packs/workloads-scheduling/05-daemonset/grade.sh
  - cka-sim/packs/workloads-scheduling/05-daemonset/metadata.yaml
  - cka-sim/packs/workloads-scheduling/05-daemonset/question.md
  - cka-sim/packs/workloads-scheduling/05-daemonset/ref-solution.sh
  - cka-sim/packs/workloads-scheduling/05-daemonset/reset.sh
  - cka-sim/packs/workloads-scheduling/05-daemonset/setup.sh
  - cka-sim/packs/workloads-scheduling/06-static-pod/grade.sh
  - cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml
  - cka-sim/packs/workloads-scheduling/06-static-pod/question.md
  - cka-sim/packs/workloads-scheduling/06-static-pod/ref-solution.sh
  - cka-sim/packs/workloads-scheduling/06-static-pod/reset.sh
  - cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh
  - cka-sim/packs/workloads-scheduling/07-native-sidecar/grade.sh
  - cka-sim/packs/workloads-scheduling/07-native-sidecar/metadata.yaml
  - cka-sim/packs/workloads-scheduling/07-native-sidecar/question.md
  - cka-sim/packs/workloads-scheduling/07-native-sidecar/ref-solution.sh
  - cka-sim/packs/workloads-scheduling/07-native-sidecar/reset.sh
  - cka-sim/packs/workloads-scheduling/07-native-sidecar/setup.sh
  - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/grade.sh
  - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/metadata.yaml
  - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/ref-solution.sh
  - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/reset.sh
  - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/setup.sh
  - cka-sim/packs/workloads-scheduling/coverage.yaml
  - cka-sim/packs/workloads-scheduling/manifest.yaml
  - cka-sim/scripts/lint-coverage.sh
  - cka-sim/scripts/test.sh
  - cka-sim/tests/cases/lint_coverage_completeness.sh
  - cka-sim/tests/cases/lint_coverage_schema.sh
  - cka-sim/tests/cases/setup_helpers_ensure_lab_ns.sh
  - cka-sim/tests/cases/setup_helpers_seed_deployment.sh
  - cka-sim/tests/cases/setup_helpers_seed_pv_hostpath.sh
  - cka-sim/tests/cases/setup_helpers_wait_for_ns_active.sh
  - cka-sim/traps/catalog.yaml
  - scripts/validate-local.sh
findings:
  critical: 3
  warning: 12
  info: 4
  total: 19
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-05-11T00:03:00Z
**Depth:** standard
**Files Reviewed:** 63 source files (shared libs, pack scripts, lint tooling, tests, CI glue)
**Status:** issues_found

## Summary

Phase 4 ships the Storage and Workloads-Scheduling packs, a shared `lib/setup.sh` helper surface, a new `lint-coverage.sh` matrix linter, five new trap-catalog entries, and the CI wiring to enforce the coverage rule. The scaffolding (lint-coverage shape, manifest/coverage YAML pairs, GRADE-02 compliance in graders) is solid. The defects cluster in three areas: (1) a PV node-affinity helper signature whose `operator: Exists` semantics silently defeats hostPath pinning on multi-node clusters, breaking the storage/06 data-sharing test; (2) a trap-ID reuse in storage/03 that reports a catalog message that contradicts the detected condition; (3) a CSI driver refcount gate in storage/04 whose failure mode collapses to "tear down the driver," which can break unrelated concurrent labs. Supply-chain hygiene (unsigned HTTPS manifest pulls from GitHub at setup time) and several metadata.yaml trap lists with off-topic trap IDs round out the warnings.

## Critical Issues

### CR-01: hostPath PV `operator: Exists` does not pin to a single node, breaking storage/06 writer->reader data handoff

**File:** `cka-sim/lib/setup.sh:53-84` (helper) and `cka-sim/packs/storage/06-pvc-mount-pod/setup.sh:18` (caller)

**Issue:** `cka_sim::setup::seed_pv_hostpath` emits `nodeAffinity.required.nodeSelectorTerms[*].matchExpressions[*]` with `operator: Exists` on the caller-supplied key. When the key is `kubernetes.io/hostname`, every Kubernetes node carries that label with SOME value, so the affinity selector matches EVERY node — the PV is not pinned. In storage/06-pvc-mount-pod, `q06-writer` writes `/data/marker` on one hostPath filesystem (node N_a), then the Deployment `q06-reader` (created later via ref-solution or by a candidate) is free to be scheduled on any node N_b ≠ N_a, at which point `hostPath: /tmp/q06-data` is an empty `DirectoryOrCreate` directory and grade.sh's behavioural assertion `exec probe: deploy/q06-reader /data/marker == 'q06-marker'` fails non-deterministically. The 1-CP + 2-worker target cluster will hit this whenever the scheduler spreads the two pods. The `storage/01-pvc-binding` reference question deliberately omits affinity (trap seeding), so this bug is specific to questions whose behavioural oracle depends on same-node execution.

**Fix:** Change the helper signature to accept `key=value` (or a full matchExpression) and emit `operator: In` with a concrete value list; update storage/06 to pin to a specific hostname. Minimal change:

```bash
# lib/setup.sh — swap the affinity block emitter
if [[ -n "$affinity_key" ]]; then
  local k="${affinity_key%%=*}"
  local v="${affinity_key#*=}"
  if [[ "$k" == "$v" ]]; then
    # legacy: bare key -> Exists (keep for callers that genuinely want any-node)
    affinity_block=$(cat <<AFF
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: ${k}
              operator: Exists
AFF
)
  else
    affinity_block=$(cat <<AFF
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: ${k}
              operator: In
              values: ["${v}"]
AFF
)
  fi
fi
```

Then in storage/06/setup.sh, pass a real pinning value — e.g. discover a worker with `kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}'` and call `seed_pv_hostpath q06-data-pv 1Gi ReadWriteOnce Retain /tmp/q06-data "kubernetes.io/hostname=${worker}"`. This keeps writer and reader co-located. (Storage/03 and storage/05 use the same `operator: Exists` pattern but do not rely on data continuity across pods, so they are not correctness blockers; migrating them is still recommended for consistency.)

### CR-02: storage/03 records `reclaim-policy-delete-data-loss` on the INVERSE condition, showing the candidate a contradictory trap message

**File:** `cka-sim/packs/storage/03-access-modes-reclaim/grade.sh:39-42`

**Issue:** The grader records trap `reclaim-policy-delete-data-loss` when `q03-retain-pv.spec.persistentVolumeReclaimPolicy == "Retain"`. The catalog entry for that trap (`cka-sim/traps/catalog.yaml:234-244`) has `name: "PV reclaim policy set to Delete destroys data when the PVC is deleted"` and `description: "PersistentVolume reclaim policy is Delete; when the bound PVC is deleted, the underlying volume (and its data) is removed automatically. Retain preserves the volume for manual reclaim."` The grader's inline comment admits this is "inverse framing," but at runtime `cka_sim::trap::format_line` renders the catalog's canonical message, so a candidate who correctly leaves the PV on `Retain` sees: `Trap N: PV reclaim policy set to Delete destroys data ... : PersistentVolume reclaim policy is Delete; when the bound PVC is deleted, the underlying volume (and its data) is removed automatically.` — a message that directly contradicts what they did. This is actively misleading teaching feedback and undermines the phase-4 "traps as learning signal" contract.

**Fix:** Register a new catalog entry whose wording matches the detected condition (e.g., `reclaim-policy-retain-when-delete-required` with description "Business rule requires PV to delete underlying storage with its PVC, but reclaim policy is still Retain; the data will be orphaned instead of cleaned up"), reference it from the question's metadata.yaml traps list, and record THAT id in grade.sh. Keep the existing `reclaim-policy-delete-data-loss` entry for the usual direction (questions where Delete was chosen against a Retain-required rule).

### CR-03: storage/04 CSI driver refcount collapses kubectl failures to "0 users" and unconditionally tears down the shared driver

**File:** `cka-sim/packs/storage/04-csi-volumesnapshot/reset.sh:16-24`

**Issue:** The refcount gate runs

```bash
active_users=$(kubectl get pvc --all-namespaces -l cka-sim/uses=csi-hostpath \
  --field-selector "metadata.namespace!=$CKA_SIM_LAB_NS" \
  -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$active_users" == "0" ]]; then
  kubectl delete volumesnapshotclass csi-hostpath-snapshotclass --ignore-not-found
  kubectl delete storageclass csi-hostpath-sc --ignore-not-found
  kubectl delete namespace csi-hostpath --ignore-not-found --wait=false
fi
```

With `2>/dev/null` swallowing stderr and `wc -l` counting 0 on empty stdin, ANY failure of the `kubectl get` call (API timeout, RBAC deny, transient TLS error, authentication plugin hiccup) produces `active_users=0` and proceeds to rip out the cluster-wide csi-hostpath driver — including its namespace and the VolumeSnapshotClass — while OTHER concurrent labs may legitimately still have PVCs using it. This is exactly the "cannot-determine must not be misclassified as miss" pattern that `lib/traps.sh` detectors explicitly warn against (see `detect_service_label_mismatch` comment block). The blast radius is cluster-wide: every in-flight snapshot and every concurrent storage/04 run on the same cluster will break.

**Fix:** Distinguish "kubectl succeeded and listed zero users" from "kubectl failed." Capture the exit code; skip the teardown (leave the driver standing — it is a cheap, idempotent install) when the query cannot succeed. Also require BOTH (a) no other PVCs AND (b) no VolumeSnapshot resources, since a snapshot outlives its source PVC.

```bash
set +e
pvc_out=$(kubectl get pvc --all-namespaces -l cka-sim/uses=csi-hostpath \
  --field-selector "metadata.namespace!=$CKA_SIM_LAB_NS" -o name 2>/dev/null); pvc_rc=$?
snap_out=$(kubectl get volumesnapshot --all-namespaces -o name 2>/dev/null); snap_rc=$?
set -e

if (( pvc_rc != 0 )) || (( snap_rc != 0 )); then
  echo "reset: skipping driver teardown — kubectl query failed (pvc_rc=$pvc_rc snap_rc=$snap_rc)" >&2
  exit 0
fi

if [[ -z "$pvc_out" && -z "$snap_out" ]]; then
  kubectl delete volumesnapshotclass csi-hostpath-snapshotclass --ignore-not-found
  kubectl delete storageclass csi-hostpath-sc --ignore-not-found
  kubectl delete namespace csi-hostpath --ignore-not-found --wait=false
fi
```

## Warnings

### WR-01: Unsigned HTTPS manifest fetches in setup/ref-solution scripts (supply-chain)

**File:**
- `cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh:25-37`
- `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/ref-solution.sh:9`

**Issue:** Both scripts fetch YAML directly from GitHub (`raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/...`, `github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/...`) and pipe straight into `kubectl apply`. No SHA256 pin, no offline fallback, no checksum verification. If the upstream repo or the CDN is compromised, arbitrary manifests run on the lab cluster with full cluster-admin privileges. Even without compromise, the lab is unusable offline.

**Fix:** Vendor the pinned release manifests under `cka-sim/packs/storage/04-csi-volumesnapshot/vendor/` (or `cka-sim/vendor/external-snapshotter-v7.0.2/`), verify SHA256 in a one-time refresh script, and `kubectl apply -f vendor/...` from the working tree. Keep the network pull as a fallback path guarded by a CKA_SIM_ALLOW_NETWORK_FETCH env flag.

### WR-02: storage/02-storageclass-dynamic/ref-solution.sh depends on `rancher.io/local-path` without verification

**File:** `cka-sim/packs/storage/02-storageclass-dynamic/ref-solution.sh:12-19`

**Issue:** Ref-solution creates a StorageClass with `provisioner: rancher.io/local-path` and expects WaitForFirstConsumer binding to succeed. The provisioner is assumed pre-installed "per exercise 12" (comment), but there is no preflight in the question's setup and no lint that surfaces the dependency. If a candidate runs the drill on a fresh kubeadm cluster, the ref-solution-based round-trip and `cka-sim drill storage` both hang at PVC Bound wait until the 90s timeout.

**Fix:** Add an explicit preflight in setup.sh that fails loudly if no suitable dynamic provisioner is installed (check cluster-scope StorageClasses with a provisioner other than `kubernetes.io/no-provisioner`), mirroring storage/04's snapshotter preflight pattern.

### WR-03: metadata.yaml declares off-topic traps

**File:**
- `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/metadata.yaml:7` (`hostpath-pv-without-nodeaffinity`)
- `cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/metadata.yaml:8` (`hostpath-pv-without-nodeaffinity`)
- `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/metadata.yaml:8` (`service-selector-empty-endpoints` — no Service in the question)
- `cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml:6` (`kubelet-runtime-flag-in-kubeconfig` — question explicitly forbids editing kubeconfig, so the trap cannot be exercised by the candidate)

**Issue:** GRADE-04 mandates ≥3 traps per question, and `lint-packs.sh` enforces catalog membership, but there is no lint that the listed traps are RELEVANT to the question scenario. Listing `hostpath-pv-without-nodeaffinity` on a ConfigMap/Secret question and on a node-affinity question is filler: no setup asset or grade detector references it. That breaks the "metadata.traps is the candidate's study checklist" contract — candidates studying the question's traps will chase red herrings.

**Fix:** Replace filler trap IDs with on-topic ones. For questions where only 1-2 real traps exist, register new on-topic catalog entries rather than padding with unrelated IDs. For 06-static-pod, drop `kubelet-runtime-flag-in-kubeconfig` (the question constraints forbid the path that would hit it) and replace with a static-pod-specific trap.

### WR-04: storage/03-access-modes-reclaim trap detector scopes cluster-wide RWX PV count

**File:** `cka-sim/packs/storage/03-access-modes-reclaim/grade.sh:28-33`

**Issue:** `rwx_names=$(kubectl get pv -o jsonpath='{.items[?(@.spec.accessModes[0]=="ReadWriteMany")].metadata.name}')` counts RWX PVs cluster-wide. If any other question, user, or long-running workload left a RWX PV in the cluster, `rwx_count > 0` and the trap is suppressed even though this question's PVs still mismatch. Produces false negatives in trap detection.

**Fix:** Scope the query to this question's PVs by label selector — seed `cka-sim/question-id=storage-access-modes-reclaim` on q03-retain-pv and q03-delete-pv in setup (the helper already emits no labels, so either extend the helper or attach labels post-apply), then filter `kubectl get pv -l cka-sim/question-id=storage-access-modes-reclaim`.

### WR-05: storage/03 pairs `pv-accessmodes-mismatch` with `pvc-accessmode-rwx-on-rwo-sc` using a single detection condition

**File:** `cka-sim/packs/storage/03-access-modes-reclaim/grade.sh:30-33`

**Issue:** Both traps are recorded together on `phase==Pending && rwx_count==0`. The `pvc-accessmode-rwx-on-rwo-sc` catalog entry describes a StorageClass-level RWO limitation, but this question uses manual PV binding (`storageClassName: manual`), not a dynamic RWO-only SC. The two traps represent different root causes; collapsing them onto one condition misleads the candidate's learning.

**Fix:** Only record `pv-accessmodes-mismatch` for this scenario. Remove `pvc-accessmode-rwx-on-rwo-sc` from the metadata and the detection block.

### WR-06: storage/02 reset tears down cluster-scoped StorageClass without refcount

**File:** `cka-sim/packs/storage/02-storageclass-dynamic/reset.sh:10`

**Issue:** `kubectl delete storageclass fast-ssd --ignore-not-found` is unconditional. If a candidate happened to name their own SC `fast-ssd` or another lab uses the same name (a real risk given how generic the name is), reset stomps it. Not catastrophic for a serialised single-user drill loop, but dangerous once multiple candidates share a cluster.

**Fix:** Label the SC in ref-solution/docs (`cka-sim/uses: storage-storageclass-dynamic`) and gate the delete on `kubectl get sc fast-ssd -l cka-sim/uses=storage-storageclass-dynamic -o name` returning a hit.

### WR-07: storage/05 and storage/03 helpers do not label PVs for pack-scoped cleanup

**File:**
- `cka-sim/packs/storage/03-access-modes-reclaim/setup.sh:17,20`
- `cka-sim/packs/storage/05-wait-for-first-consumer/setup.sh:36`
- `cka-sim/lib/setup.sh:67-83`

**Issue:** `seed_pv_hostpath` does not attach `cka-sim/pack` or `cka-sim/question-id` labels, unlike `ensure_lab_ns` and some direct PVC applies. Cluster-scoped PVs are therefore untrackable by pack lint / coverage tools and invisible to WR-04's suggested filter. The Phase 3 reference (`storage/01-pvc-binding/setup.sh:22-24`) DOES apply a direct PVC with those labels, so the pack already has the pattern — it just did not get propagated into the helper.

**Fix:** Extend the helper signature (or add an `_apply_labels` stage) to label every emitted PV with `cka-sim/pack` and `cka-sim/question-id` sourced from caller-exported env. Retrofit all callers.

### WR-08: workloads/02 patch uses `op: add` on template annotations, non-idempotent across re-runs

**File:** `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/setup.sh:59-60`

**Issue:** `[{"op":"add","path":"/spec/template/metadata/annotations","value":{"cka-sim/rev":"2"}}]` REPLACES the annotations map on every run (JSON-patch `add` with a map value replaces the existing map). On a second consecutive run (before reset), any annotations the previous setup or a candidate added on the template are clobbered. More importantly, the patch does not reliably trigger a new revision on the second run because the map value is identical to what's already there — no template hash change, no rollout, and `kubectl rollout undo` then has no prior revision to return to.

**Fix:** Use a unique annotation value per setup run (timestamp / random suffix), and use `op: replace` if the path already exists or create the annotations map first via a `test`/`add` pair. Alternatively switch to `kubectl patch --type=strategic` with a merge so a timestamped annotation always registers as a change:

```bash
kubectl patch deployment web -n "$CKA_SIM_LAB_NS" --type=strategic \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"cka-sim/seeded-at\":\"$(date -u +%s)\"}}}}}"
```

### WR-09: workloads/06-static-pod reset only cleans node-01

**File:** `cka-sim/packs/workloads-scheduling/06-static-pod/reset.sh:11`

**Issue:** `ssh ... node-01 'sudo rm -f /etc/kubernetes/manifests/q06-static-nginx.yaml'` runs only against node-01. If a candidate (correctly or otherwise) dropped the manifest on node-02 or the control plane, the mirror pod persists after reset and the next setup sees an unexpected mirror pod in `default`. Grade is in `default` ns, not the lab ns, so it escapes the ns-delete sweep.

**Fix:** Iterate `kubectl get nodes -o name` and attempt the rm on each reachable node. Keep `2>/dev/null || true` for best-effort semantics.

### WR-10: storage/06 reset does not wait for ns-Terminating before returning, colliding with hostPath filesystem state

**File:** `cka-sim/packs/storage/06-pvc-mount-pod/reset.sh:7-10`

**Issue:** Async `kubectl delete namespace ... --wait=false` returns immediately. The PV (cluster-scoped) is deleted next, but the bound PVC and pods are still Terminating. kubelet may not have finalized the hostPath unmount, so `/tmp/q06-data/marker` remains on the underlying node until the next kubelet GC cycle. A subsequent setup then sees a stale marker written by the prior run's writer, not the new one — the grader's behavioural assertion can pass against the wrong data on the first re-run before the new writer completes. This is an edge case (grade wait for writer Succeeded is 90s) but it can mask regressions in the writer path.

**Fix:** In setup.sh, remove the hostPath directory before the writer runs: best-effort `ssh ${worker_node} sudo rm -rf /tmp/q06-data` or invoke an init container on the writer that wipes `/data` before writing.

### WR-11: CI Coverage-lint step runs BEFORE pack lint, so a broken pack can mask a coverage error

**File:** `.github/workflows/validate.yml:59-65`

**Issue:** In the `bash-tests` job, `bash cka-sim/scripts/lint-coverage.sh` runs before `bash cka-sim/scripts/test.sh` (which internally runs trap + pack lint before coverage). The ordering means if a pack manifest.yaml is malformed (e.g., missing `questions:`), the standalone coverage step fails with a confusing "manifest has no questions" message, obscuring the real pack-lint root cause that `test.sh` would surface.

**Fix:** Drop the standalone `Coverage lint` step and rely on `test.sh` (which already runs all three lints in the right order). Or reorder so `bash cka-sim/scripts/lint-packs.sh` runs first.

### WR-12: storage/04 setup.sh treats `kubectl wait` failures as success

**File:** `cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh:30,37,109`

**Issue:** All three `kubectl wait` calls terminate with `2>/dev/null || true`. If snapshot-controller never becomes Available or the PVC never binds, setup exits 0 and the question enters an unusable state — grade.sh then reports failures that look like a candidate error rather than a broken environment. `set -euo pipefail` at the top is neutralised by the explicit `|| true`.

**Fix:** Keep `2>/dev/null` for readability but drop `|| true` on the critical gate (snapshot-controller Available). Emit a loud error and exit 1 if the wait times out, so the runner can distinguish "setup broken" from "candidate broken."

## Info

### IN-01: `cka_sim::setup::wait_for_ns_active` integer truncation on non-5-multiple timeout

**File:** `cka-sim/lib/setup.sh:33-47`

**Issue:** `iterations=$(( timeout / 5 ))` truncates. timeout=12 yields 2 iterations ≈ 10s actual wait instead of 12s. All current callers pass 120, so not a live bug.

**Fix:** Round up: `iterations=$(( (timeout + 4) / 5 ))`.

### IN-02: `seed_deployment` emits blank `spec:` line when `--sa` not passed

**File:** `cka-sim/lib/setup.sh:101-102,130-131`

**Issue:** When `sa=""`, `sa_block=""` and the heredoc emits a bare blank line between `spec:` and `containers:`. YAML-valid but cosmetically noisy and trips shellcheck SC2016 if anyone rewrites the helper.

**Fix:** Guard the block insertion with a conditional: only emit the line when `sa_block` is non-empty.

### IN-03: workloads/08 `kubectl label nodes ... gpu- --overwrite` overuses `--overwrite`

**File:** `cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/reset.sh:15`

**Issue:** `--overwrite` is only relevant when SETTING a label. For removal (`key-` syntax), the flag is a no-op; kubectl actually warns on newer versions that the flag is unnecessary. Not a correctness issue, just noise.

**Fix:** Drop `--overwrite` from the removal call.

### IN-04: Several grade.sh files inline `TOTAL/PASSED` accumulator updates instead of using helpers

**File:**
- `cka-sim/packs/storage/06-pvc-mount-pod/grade.sh:34-43`
- `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/grade.sh:17-25,36-44`
- `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/grade.sh:36-57`
- `cka-sim/packs/workloads-scheduling/05-daemonset/grade.sh:34-42`
- `cka-sim/packs/workloads-scheduling/07-native-sidecar/grade.sh:30-38`
- `cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/grade.sh:29-49`

**Issue:** The grade-lib contract in `lib/grade.sh` exposes assertion helpers that own the TOTAL/PASSED bookkeeping. Six graders bypass the helpers and poke `CKA_SIM_GRADE_TOTAL` / `CKA_SIM_GRADE_PASSED` directly for behavioural probes (exec, kubectl rollout status, line count). This scatters accumulator semantics across the corpus and makes future lib changes risky. Not a correctness bug — the inline math is correct — but it erodes the single-responsibility boundary the helper library was designed to provide.

**Fix:** Add a generic helper to `lib/grade.sh`:

```bash
cka_sim::grade::assert_custom <label> <weight> <expr-that-exits-0-on-pass>
```

and retrofit the inline blocks to call it. Keeps the "one module owns the counters" invariant.

---

_Reviewed: 2026-05-11T00:03:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
