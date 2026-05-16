---
phase: 04-storage-workloads-scheduling-packs
plan: 16
subsystem: cka-sim-packs
tags: [pack-manifest, lint-coverage, ci-integration, phase-closure]
dependency-graph:
  requires: [04-03, 04-04, 04-05, 04-06, 04-07, 04-08, 04-09, 04-10, 04-11, 04-12, 04-13, 04-14, 04-15]
  provides: [storage-pack-manifest-final, workloads-pack-manifest-final, coverage-lint-in-ci]
  affects: [phase-04-closure]
tech-stack:
  added: []
  patterns: [pack-manifest-enumeration, belt-and-braces-ci-step]
key-files:
  created: []
  modified:
    - cka-sim/packs/storage/manifest.yaml
    - cka-sim/packs/workloads-scheduling/manifest.yaml
    - cka-sim/scripts/test.sh
    - scripts/validate-local.sh
    - .github/workflows/validate.yml
decisions:
  - "CI surfaces coverage lint as a named step BEFORE test.sh (belt-and-braces: test.sh also invokes it internally, but a named step surfaces failures in the GitHub Checks tab rather than burying them in aggregate test output)"
  - "validate-local.sh walks cka-sim/ with the same python3 yaml.safe_load probe as skeletons/exercises — keeps the lint fabric uniform across all yaml-carrying trees"
metrics:
  duration: 4m
  completed: 2026-05-10
  tasks: 2
  files-modified: 5
requirements: [PACK-01, PACK-02, PACK-06, PACK-07]
---

# Phase 4 Plan 16: Pack manifest finalisation + lint-coverage CI wiring Summary

Final Wave-4 integration plan closes Phase 4 by enumerating all 14 authored questions in their respective pack manifests (storage: 6, workloads-scheduling: 8), inserting lint-coverage.sh into the local + CI test chain, and adding a named `Coverage lint` GitHub Actions step so coverage failures surface as a dedicated check.

## What was built

**Task 1 — Pack manifests (commit `90c395f`)**
- `cka-sim/packs/storage/manifest.yaml`: expanded from 2 questions (01-pvc-binding + 05-wait-for-first-consumer) to **6 questions** by adding 02-storageclass-dynamic, 03-access-modes-reclaim, 04-csi-volumesnapshot, 06-pvc-mount-pod. Description updated to `"Storage 10% domain pack (PACK-01) -- full v1.35 Tracker coverage."`
- `cka-sim/packs/workloads-scheduling/manifest.yaml`: expanded from 1 question (01-deployment-requests) to **8 questions** by adding 02-rolling-update-rollback, 03-configmap-secret-env-volume, 04-hpa-metrics-server, 05-daemonset, 06-static-pod, 07-native-sidecar, 08-nodeselector-affinity-taints. Description updated to reflect full v1.35 Tracker coverage including CG-06 + CG-08.
- Every `id:` cross-checked against its dir's `metadata.yaml` id (14/14 match).
- `estimatedMinutes` values match each question's authored metadata.

**Task 2 — Lint chain wiring (commit `ca1e94d`)**
- `cka-sim/scripts/test.sh`: inserted `step 3: lint coverage` between `lint-packs` and `tests/run.sh`; renumbered `run bash unit cases` to step 4.
- `scripts/validate-local.sh`: extended the for-dir loop to walk `cka-sim` alongside `skeletons` + `exercises`; appended an `=== cka-sim coverage lint ===` block that invokes `cka-sim/scripts/lint-coverage.sh` after the yamllint pass, incrementing `errors` on failure.
- `.github/workflows/validate.yml`: added a named `Coverage lint` step in the `bash-tests` job, positioned BEFORE the existing `Run cka-sim test suite` step so CI surfaces coverage failures as a dedicated GitHub Check.

## Verification

All 7 VERIFICATION `must_haves` from CONTEXT:

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Storage pack Tracker coverage | `bash cka-sim/scripts/lint-coverage.sh storage` exits 0 |
| 2 | Workloads pack Tracker coverage | `bash cka-sim/scripts/lint-coverage.sh workloads-scheduling` exits 0 |
| 3 | Metadata schema compliance | `bash cka-sim/scripts/lint-packs.sh` exits 0 (51 checks pass) |
| 4 | Trap registration integrity | subsumed in lint-packs (same run) |
| 5 | `cka-sim drill <pack>` live round-trip | **MANUAL** — handed off to user on 1+2 cluster (see §Next steps) |
| 6 | Trap-catalog schema | `bash cka-sim/scripts/lint-traps.sh` exits 0 (20 entries) |
| 7 | Tracker coverage 100% | `bash cka-sim/scripts/lint-coverage.sh` exits 0 (2 packs checked, 0 warnings) |

**Full automated chain (local):**
```
lint-traps     ✓ 20 entries
lint-packs     ✓ 51 checks
lint-coverage  ✓ 2 packs, 0 warnings
tests/run.sh   ✓ 29/29 unit cases
```

6 of 7 `must_haves` (all static / automated) are green. Criterion 5 (live-cluster `cka-sim drill` round-trip per pack) is left to the user on their 1+2 cluster per CONTEXT §Runtime + Verification — same model as Phase 3.

## Manifest question counts

| Pack | Questions | IDs |
|------|-----------|-----|
| storage | 6 | storage-pvc-binding, storage-storageclass-dynamic, storage-access-modes-reclaim, storage-csi-volumesnapshot, storage-wait-for-first-consumer, storage-pvc-mount-pod |
| workloads-scheduling | 8 | workloads-deployment-requests, workloads-rolling-update-rollback, workloads-configmap-secret-env-volume, workloads-hpa-metrics-server, workloads-daemonset, workloads-static-pod, workloads-native-sidecar, workloads-nodeselector-affinity-taints |

## CI integration

`.github/workflows/validate.yml` bash-tests job now runs:

1. `actions/checkout@v4`
2. **`Coverage lint`** — `bash cka-sim/scripts/lint-coverage.sh` (new named step, surfaces coverage failures directly)
3. `Run cka-sim test suite` — `bash cka-sim/scripts/test.sh` (internally chains lint-traps → lint-packs → lint-coverage → unit cases)

Belt-and-braces: lint-coverage runs twice per CI run. Intentional — the named step is for signal visibility, the test.sh chain is for local-dev uniformity.

## Live-cluster manual verification checklist (criterion 5)

Run on CP node once merged:

```
cka-sim drill storage
  -> expect 6 questions enumerated in order
  -> pick at least one per-question, run setup.sh, verify expected fail-state
  -> apply solution, run grade.sh, expect PASS
  -> run teardown.sh, expect clean namespace

cka-sim drill workloads-scheduling
  -> expect 8 questions enumerated in order
  -> same per-question loop
```

Document outcomes in `.planning/phases/04-storage-workloads-scheduling-packs/04-VERIFICATION.md` on completion.

## Deviations from Plan

None — plan executed exactly as written.

## Deferred Issues

**Pre-existing: `scripts/validate-local.sh` python3 interpreter shim on Windows**
- Discovered during Task 2 verification.
- `/c/Users/.../WindowsApps/python3` is a Microsoft Store shim that prints "Python was not found" instead of invoking the real Python 3.12 (available as `python`). All YAML files (skeletons AND cka-sim) then FAIL the `python3 -c 'yaml.safe_load'` probe.
- Pre-existing: reproduced with `git stash` BEFORE Plan 04-16 changes — 23 skeleton files failed. Plan 04-16 only extended the loop to walk `cka-sim/` (61 total now).
- **CI impact:** none — GitHub Actions Ubuntu runners have a real `python3` interpreter, so the script exits 0 there.
- Logged in `.planning/phases/04-storage-workloads-scheduling-packs/deferred-items.md` for a future chore plan.

## Phase 4 closure readiness

- All 7 VERIFICATION `must_haves` satisfied (6 automated, 1 manual live-cluster handoff)
- 14 authored questions registered in 2 domain pack manifests
- 20-entry trap catalog green
- Tracker coverage 100% for storage + workloads-scheduling
- Lint chain uniform across local (test.sh, validate-local.sh) + CI (validate.yml)

Ready for user to run `cka-sim drill storage` + `cka-sim drill workloads-scheduling` on 1+2 cluster.

## Self-Check: PASSED

- `cka-sim/packs/storage/manifest.yaml` FOUND (6 questions)
- `cka-sim/packs/workloads-scheduling/manifest.yaml` FOUND (8 questions)
- `cka-sim/scripts/test.sh` FOUND (lint-coverage wired)
- `scripts/validate-local.sh` FOUND (cka-sim walk + lint-coverage wired)
- `.github/workflows/validate.yml` FOUND (Coverage lint step added)
- commit 90c395f FOUND (Task 1)
- commit ca1e94d FOUND (Task 2)
