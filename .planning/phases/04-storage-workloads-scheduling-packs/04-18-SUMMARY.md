---
phase: 04-storage-workloads-scheduling-packs
plan: 18
subsystem: workloads-scheduling/08-nodeselector-affinity-taints
tags: [gap-closure, bug-fix, dynamic-discovery, node-selector, taints]
dependency_graph:
  requires: []
  provides: [BUG-3-closed, workloads-08-live-runnable]
  affects: [04-VERIFICATION.md MH-5]
tech_stack:
  added: []
  patterns: [dynamic-worker-discovery via kubectl label selector]
key_files:
  created: []
  modified:
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/setup.sh
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/reset.sh
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/ref-solution.sh
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/grade.sh
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/question.md
decisions:
  - "Soft-fail discovery in reset.sh + grade.sh (|| echo '') so cleanup and grading continue even if API is unreachable"
  - "Hard-fail discovery in setup.sh + ref-solution.sh (exit 1) because a missing worker makes the question unrunnable"
  - "question.md uses <target-node> placeholder + 'Find your target node' section rather than embedding a dynamic shell expression inline in prose"
  - "VERIFICATION.md fix field under-specified (named 3 files); grade.sh + question.md also required migration or grader assertions 3+4 would always fail"
metrics:
  duration: 15m
  completed: "2026-05-11T12:32:34Z"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 5
---

# Phase 04 Plan 18: BUG-3 Dynamic Worker Discovery for workloads/08 Summary

Dynamic worker discovery replacing hardcoded `node-02` across all 5 files in workloads-scheduling question 08, using `kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --no-headers -o jsonpath='{.items[0].metadata.name}'` as the single shared idiom.

## What Was Done

BUG-3 (cka-sim/results.txt line 493: `Error from server (NotFound): nodes "node-02" not found`) was caused by 5 files in `cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/` hardcoding the literal K8s node name `node-02`. On the user's 1+2 kubeadm cluster the K8s node names visible to `kubectl get nodes` do not match the SSH aliases from Phase 1 BOOT-03.

All 5 files were migrated to the shared discovery idiom. The VERIFICATION.md `fix:` field had under-specified the scope (named only setup.sh + reset.sh + ref-solution.sh); grade.sh assertions 3+4 and question.md also hardcoded `node-02` and would have caused the grader to always fail placement+label assertions and the candidate prompt to point at a nonexistent node.

## Discovery Idiom (single source of truth)

```bash
target_node=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  --no-headers -o jsonpath='{.items[0].metadata.name}')
```

Identical selector and jsonpath across all four scripts ensures a single drill invocation (setup → grade → ref → reset) targets the same worker consistently.

## Per-File Changes

| File | Change | Fail mode |
|------|--------|-----------|
| setup.sh | Discovery + hard-fail guard; taint applied to `${target_node}` | `exit 1` if no worker |
| reset.sh | Discovery + soft-fail guard; untaint+unlabel only if discovery succeeds | silent skip |
| ref-solution.sh | Discovery + hard-fail guard; labels `${target_node}` | `exit 1` if no worker |
| grade.sh | Discovery + soft-fail; assertions 3+4 compare against `$target_node` | auto-FAIL assertions |
| question.md | `<target-node>` placeholder + "Find your target node" section with discovery command | n/a |

## Commits

- `3ec6a36` fix(04-18): dynamic worker discovery in setup.sh + reset.sh
- `d3a1fac` fix(04-18): dynamic worker discovery in ref-solution.sh + grade.sh
- `e76f764` fix(04-18): dynamic worker discovery in question.md

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Comment in setup.sh contained literal `node-02`**
- **Found during:** Task 1 verification
- **Issue:** The plan's target post-state comment read `SSH aliases node-01/node-02` — a `node-02` literal that would have failed the zero-literal acceptance check
- **Fix:** Shortened comment to `SSH aliases` without naming the specific aliases
- **Files modified:** setup.sh
- **Commit:** 3ec6a36

None beyond the above — plan executed as written for all structural changes.

## Known Stubs

None. All 5 files are fully wired to the dynamic discovery idiom.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `target_node` variable is quoted at every use site (`"${target_node}"`); node names are RFC 1123 labels validated by the API server and cannot contain shell metacharacters (T-04-18-01 mitigated). Control-plane exclusion via selector prevents accidental taint of system nodes (T-04-18-03 mitigated).

## Next Step

Live-drill re-verification (paired with 04-17/BUG-1): run `cka-sim drill workloads-scheduling --question 08` on the 1+2 cluster to close MH-5 in 04-VERIFICATION.md.

## Self-Check: PASSED

- setup.sh exists and contains discovery idiom: FOUND
- reset.sh exists and contains discovery idiom: FOUND
- ref-solution.sh exists and contains discovery idiom: FOUND
- grade.sh exists and contains discovery idiom: FOUND
- question.md exists and contains discovery idiom: FOUND
- Zero `node-02` literals in q08 directory: CONFIRMED
- Commit 3ec6a36: FOUND
- Commit d3a1fac: FOUND
- Commit e76f764: FOUND
- bash cka-sim/scripts/test.sh: exit 0 (29/29 cases)
- bash cka-sim/scripts/lint-packs.sh: exit 0 (51 checks)
