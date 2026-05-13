---
status: complete
phase: 04-storage-workloads-scheduling-packs
source: 04-01-SUMMARY.md through 04-16-SUMMARY.md
started: 2026-05-13T15:31:00Z
updated: 2026-05-13T16:04:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Storage Pack Question Coverage
expected: `packs/storage/` contains 6 questions covering all Tracker checkboxes in the Storage domain, including `04-csi-volumesnapshot` and `05-wait-for-first-consumer`.
result: pass

### 2. Workloads-Scheduling Pack Question Coverage
expected: `packs/workloads-scheduling/` contains 8 questions covering all Tracker checkboxes, including a native-sidecar question (07-native-sidecar) and a metrics-server/HPA question (04-hpa-metrics-server).
result: pass

### 3. Metadata Schema Compliance
expected: Every question under both packs has `metadata.yaml` with `id`, `domain`, `estimatedMinutes` (4-12 range), `verified_against: "1.35"`, `traps: []` (≥3 IDs), `references: []`. `lint-packs.sh` exits 0 confirming this.
result: pass

### 4. Trap ID Registration Integrity
expected: Every trap ID referenced in any question's metadata exists in `traps/catalog.yaml`. No orphan references. `lint-packs.sh` pass E confirms this.
result: pass

### 5. Coverage Lint 100%
expected: `bash cka-sim/scripts/lint-coverage.sh` exits 0 reporting both packs at 100% Tracker coverage with 0 warnings.
result: pass

### 6. Live Drill — Storage Pack
expected: `cka-sim drill storage` on the CP node can run every question in the storage pack without error. Setup creates expected resources, grading works, reset cleans up.
result: pass

### 7. Live Drill — Workloads-Scheduling Pack
expected: `cka-sim drill workloads-scheduling` on the CP node can run every question in the workloads-scheduling pack without error. Setup creates expected resources, grading works, reset cleans up.
result: issue
reported: "3 of 8 questions failed: Q05-daemonset got 3/4 (toleration jsonpath returns duplicate 'Exists Exists' for two tolerations with same key), Q06-static-pod setup failed (SSH to worker not available), Q08-nodeselector-affinity-taints got 3/4 (likely pod reschedule timing or label state issue)"
severity: major

## Summary

total: 7
passed: 6
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "All 8 workloads-scheduling questions round-trip without error"
  status: failed
  reason: "User reported: 3 of 8 questions failed: Q05-daemonset got 3/4 (toleration jsonpath returns duplicate 'Exists Exists' for two tolerations with same key), Q06-static-pod setup failed (SSH to worker not available), Q08-nodeselector-affinity-taints got 3/4 (likely pod reschedule timing or label state issue)"
  severity: major
  test: 7
  root_cause: |
    Q05: grade.sh assertion 3 uses jsonpath filter `tolerations[?(@.key=="node-role.kubernetes.io/control-plane")].operator` which returns "Exists Exists" (two matches for NoSchedule + NoExecute tolerations) instead of single "Exists". assert_field_eq does exact string match so it fails.
    Q06: Requires passwordless SSH to worker nodes (Phase 1 bootstrap prerequisite not met on this cluster). Not a code bug — blocked by environment.
    Q08: ref-solution labels node + patches deployment, but grade.sh assertion 3 (all replicas on target node) likely fails due to rollout timing — old pods may still be terminating or new pods not yet scheduled when grade runs.
  artifacts:
    - path: "cka-sim/packs/workloads-scheduling/05-daemonset/grade.sh"
      issue: "jsonpath filter returns space-separated duplicates for multi-toleration match"
    - path: "cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/grade.sh"
      issue: "assertion 3 may race with pod reschedule after deployment patch"
  missing:
    - "Q05: Change assertion 3 to use grep/contains check for 'Exists' rather than exact equality, or use a jsonpath that selects only one toleration"
    - "Q08: Add a kubectl rollout status wait or pod-ready wait before checking nodeName placement"
  debug_session: ""
