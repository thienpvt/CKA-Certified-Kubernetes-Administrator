---
plan: 17-04
phase: 17-v1-0-2-backlog-cleanup
requirements: [BLG-05]
status: complete
date: 2026-05-19
---

# Plan 17-04 Summary — BLG-05 fixture regen

## Outcome

Both BLG-05 reds closed. The v1.0.1-carry-forward unit suite reds (`storage__02-storageclass-dynamic` and `workloads-scheduling__05-daemonset`) flip from FAIL to PASS. Test suite is fully green: **86/86 cases pass, 0 reds**.

## Root Causes

| Red | Root cause | Fix |
|-----|-----------|-----|
| `storage__02-storageclass-dynamic` | `post-ref-solution/baseline.json` incorrectly contained `fast-ssd` (the candidate-authored StorageClass) in both `resources` and `resource_list`. The Phase 07.1 grading-honesty contract requires baseline.json to capture state BEFORE the candidate works — so post-ref-solution baseline must equal post-setup baseline byte-for-byte. The grader's `assert_resource_candidate_authored` was seeing fast-ssd as pre-existing and scoring 0/1 instead of 1/1. | `cp cka-sim/tests/fixtures/.../post-setup/baseline.json cka-sim/tests/fixtures/.../post-ref-solution/baseline.json` |
| `workloads-scheduling__05-daemonset` | The kubectl stub's `post-ref-solution/.fixtures.json` was missing the `get daemonset q05-node-agent -n ... -o jsonpath={.status.numberReady}` entry. The grader's assertion 2 (`numberReady == desiredNumberScheduled`) read empty stdout, comparison failed, score was 3/4 instead of 4/4. | Added the missing fixture entry returning `numberReady: "1"` (matches the existing `desiredNumberScheduled: "1"`). Fixture entry count grew 10 → 11. |

## Files Modified (2)

- `cka-sim/tests/fixtures/grading-honesty/storage__02-storageclass-dynamic/post-ref-solution/baseline.json` — overwritten to match post-setup byte-for-byte (only `app-cache` PVC; no `fast-ssd`).
- `cka-sim/tests/fixtures/grading-honesty/workloads-scheduling__05-daemonset/post-ref-solution/.fixtures.json` — added `numberReady` jsonpath entry (line between `desiredNumberScheduled` and the tolerations entries).

## Test Suite Delta

| Metric | Before | After |
|--------|--------|-------|
| Total cases | 86 | 86 |
| Passing | 84 | **86** |
| Failing | 2 (BLG-05) | **0** |
| `bash cka-sim/scripts/test.sh` exit code | 1 (BLG-05 propagated) | **0** |

## Sibling-Pair Spot-Checks (Phase 07.1 Baseline-Equivalence Contract)

3 sibling pairs spot-checked diff-clean (post-setup baseline.json byte-identical to post-ref-solution baseline.json):

- ✓ `services-networking__05-kube-proxy-mode`
- ✓ `storage__01-pvc-binding`
- ✓ `cluster-architecture__01-rbac-viewer`

The contract holds across the broader fixture corpus; the storage/02 divergence was an isolated regen mistake.

## Acceptance Criteria

| Check | Result |
|-------|--------|
| storage/02 baseline byte-identical to post-setup | ✓ (`diff` produces no output) |
| storage/02 contains no `fast-ssd` | ✓ |
| daemonset fixture has `numberReady` entry | ✓ (returns `"1"`) |
| daemonset fixture entry count grew to 11 | ✓ |
| `bash cka-sim/tests/run.sh` exits 0 with all 86 cases passing | ✓ (`✓ all 86 case(s) passed`) |
| 3 sibling fixtures preserve baseline-equivalence | ✓ |
