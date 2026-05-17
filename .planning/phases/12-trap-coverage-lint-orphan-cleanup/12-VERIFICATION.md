---
phase: 12-trap-coverage-lint-orphan-cleanup
status: passed
verified: 2026-05-17
---

# Phase 12 — Verification

## test.sh Baseline

**4 pre-existing failures from Phase 10/11 (pending live-cluster UAT):**

1. `cluster-architecture__04-pss-enforce`
2. `storage__01-pvc-binding`
3. `storage__02-storageclass-dynamic`
4. `workloads-scheduling__05-daemonset`

These come from Phase 10/11 static fixes whose acceptance gates on live-cluster drills. They are NOT introduced by Phase 12 work. Per the user's relaxed Plan 12-05 acceptance, the test.sh requirement is "no NEW failures introduced by phase 12 work" — satisfied.

**Phase 12 introduces NO new failures.** All 79 unit cases (78 pre-existing + new `lint_trap_coverage`) either pass or fall into the 4-failure baseline above. The new `lint_trap_coverage` case is verified passing.

## Lint Results

- `bash cka-sim/scripts/lint-trap-coverage.sh` — exit 0
  - 34 questions checked
  - 11 dynamic-id warnings (graders using `record_trap "$var"` — coverage assumed)
- `bash cka-sim/scripts/lint-packs.sh` — exit 0 (298 checks)
- `bash cka-sim/scripts/test.sh` — exit 1 ONLY due to the pre-existing 4-failure baseline above. No new lint or unit case failures introduced by Phase 12.

## ROADMAP Success Criteria

1. **New script exits 0 on full pack tree only when every metadata.yaml trap entry has a matching record_trap in sibling grade.sh** — VERIFIED (`cka-sim/scripts/lint-trap-coverage.sh` exits 0; synthetic-regression branch 2 confirms exit 1 when an orphan is reintroduced).
2. **Lint added to existing CI job graph alongside lint-packs / lint-traps / lint-coverage** — VERIFIED (`cka-sim/scripts/test.sh` step 4 invokes it; CI's `bash-tests` job picks it up transitively via the existing `Run cka-sim test suite` step).
3. **storage/02, /03, /04 metadata.yaml no longer declare orphan traps** — VERIFIED (plans 12-02, 12-03, 12-04). Extended further across 16 questions in plan 12-05 under the relaxed GRADE-04 floor.
4. **Running the new lint on HEAD passes cleanly across all questions; synthetic regression fails with file:line citation** — VERIFIED (lint exits 0; case `lint_trap_coverage.sh` branch 2 asserts the citation message and exit 1).

## Files Touched

**Phase 12 commits:**
- `fc508a7` — `feat(12): add lint-trap-coverage.sh (LINT-01)`
- `92de276` — `fix(12): trim storage/02 orphan traps (BUG-M01)`
- `6e84cc0` — `fix(12): trim storage/03 orphan trap (BUG-M02)`
- `a9aa7f7` — `fix(12): trim storage/04 orphan trap (BUG-M03)`
- `6f97218` — `fix(12): relax GRADE-04 floor to permit honest trap trimming`
- `532a539` — `feat(12): wire trap-coverage lint, extend orphan cleanup, add synthetic regression`

## Notes for Reviewer

The audit forensic report originally listed 4 orphans (3 storage questions × N orphans = 4 lines). When `lint-trap-coverage.sh` first ran on HEAD it surfaced 35 orphans — most were shared seed ids (`default-sa-used`, `missing-dns-egress`, `deployment-missing-requests`, `static-pod-applied-via-kubectl-apply`, `pod-unschedulable-nodeselector-no-matching-node`) declared per-question to satisfy the old GRADE-04 `>=3` floor but never detected by any per-question grader. The PRE-12-05 GRADE-04 floor relaxation (locked by user directive) permitted honest trimming of those 31 systemic orphans alongside the 4 originally-scoped storage ones. Two graders (`workloads-scheduling/06-static-pod`, `workloads-scheduling/08-nodeselector-affinity-taints`) had zero `record_trap` calls; minimal detectors were added to keep one declared trap each (satisfying the `>=1` floor) without expanding phase scope further.

The lint is now a permanent CI guard: any future PR that adds a `traps:` entry without the matching `record_trap` call in `grade.sh` fails the `bash-tests` job with a `<file>:<line>: trap '<id>' declared but no record_trap call in grade.sh` citation.
