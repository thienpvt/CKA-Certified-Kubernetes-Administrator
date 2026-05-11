---
phase: 04-storage-workloads-scheduling-packs
plan: 17
subsystem: cka-sim/packs/storage
tags: [gap-closure, bug-fix, exec-bit, chmod, BUG-1, MH-5]
dependency_graph:
  requires: []
  provides: [storage/04-csi-volumesnapshot exec bits restored]
  affects: [MH-5 live-drill round-trip, BUG-1 closure]
tech_stack:
  added: []
  patterns: [git update-index --chmod=+x for Windows-safe exec bit restoration]
key_files:
  created: []
  modified:
    - cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh
    - cka-sim/packs/storage/04-csi-volumesnapshot/grade.sh
    - cka-sim/packs/storage/04-csi-volumesnapshot/reset.sh
    - cka-sim/packs/storage/04-csi-volumesnapshot/ref-solution.sh
decisions:
  - "Used git update-index --chmod=+x (not filesystem chmod) because Windows NTFS cannot set exec bits; git index is the source of truth for checked-in mode"
metrics:
  duration: 8m
  completed: 2026-05-11T12:28:51Z
  tasks_completed: 1
  tasks_total: 1
---

# Phase 4 Plan 17: Restore exec bit on storage/04-csi-volumesnapshot scripts Summary

Restored 100755 exec bit on all four .sh files in storage/04-csi-volumesnapshot via `git update-index --chmod=+x`, closing BUG-1 (MH-5 live-drill failure: "setup.sh not executable").

## What Was Done

BUG-1 from 04-VERIFICATION.md: Windows git dropped the exec bit on all four shell scripts in `cka-sim/packs/storage/04-csi-volumesnapshot/` during the Phase 4 octopus merges. Every other pack directory (storage/01-03, 05-06 and workloads-scheduling/01-08) had its scripts at 100755; only storage/04 regressed to 100644.

The live drill on 2026-05-11T11:40Z failed at results.txt line 157:
```
✗ /root/.../cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh not executable
```

Fix applied: `git update-index --chmod=+x` on all four scripts. Zero content change.

## Commit

**8dc3c82** — `fix(04-gap-bug1): restore exec bit on storage/04-csi-volumesnapshot scripts`

```
4 files changed, 0 insertions(+), 0 deletions(-)
mode change 100644 => 100755 cka-sim/packs/storage/04-csi-volumesnapshot/grade.sh
mode change 100644 => 100755 cka-sim/packs/storage/04-csi-volumesnapshot/ref-solution.sh
mode change 100644 => 100755 cka-sim/packs/storage/04-csi-volumesnapshot/reset.sh
mode change 100644 => 100755 cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh
```

## git ls-files -s Evidence

Post-commit index state (all four scripts 100755; data files unchanged):

```
100755 ... grade.sh
100644 ... metadata.yaml      (unchanged — data file)
100644 ... question.md        (unchanged — data file)
100755 ... ref-solution.sh
100755 ... reset.sh
100755 ... setup.sh
```

## Verification Results

- `bash cka-sim/scripts/lint-packs.sh` — exit 0 (51 checks passed, including pass D: D-12(d/e) exec-bit lint)
- `bash cka-sim/scripts/test.sh` — exit 0 (29 cases passed, including drill_orchestration_order which asserts all four scripts executable)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — chmod-only index change, no new trust boundary introduced.

## Next Step

BUG-1 is closed at the git level. MH-5 live round-trip requires user to re-run `cka-sim drill storage --question 04` on the 1+2 cluster after merging this branch. Paired with 04-18 (BUG-3 fix) for full gap closure.

## Self-Check: PASSED

- `cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh` — 100755 in index: CONFIRMED
- `cka-sim/packs/storage/04-csi-volumesnapshot/grade.sh` — 100755 in index: CONFIRMED
- `cka-sim/packs/storage/04-csi-volumesnapshot/reset.sh` — 100755 in index: CONFIRMED
- `cka-sim/packs/storage/04-csi-volumesnapshot/ref-solution.sh` — 100755 in index: CONFIRMED
- `metadata.yaml` — 100644 in index: CONFIRMED
- `question.md` — 100644 in index: CONFIRMED
- Commit 8dc3c82 exists: CONFIRMED
- `lint-packs.sh` exit 0: CONFIRMED
- `test.sh` exit 0: CONFIRMED
