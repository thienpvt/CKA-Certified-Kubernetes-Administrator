---
phase: 06-troubleshooting-pack
plan: 03
subsystem: cka-sim troubleshooting pack
tags: [troubleshooting, retrofit, imagepullbackoff, phase-06]
dependency_graph:
  requires: [PACK-05, PACK-06, PACK-07]
  provides: [troubleshooting-deploy-svc-mismatch-retrofit, imagepullbackoff-wrong-tag-coverage]
  affects: [cka-sim/packs/troubleshooting/01-deploy-svc-mismatch, cka-sim/traps/catalog.yaml]
tech_stack:
  added: []
  patterns: [shared setup helpers, trap side-effect detector, phase-06 fixture tree]
key_files:
  created:
    - cka-sim/tests/fixtures/phase-06/troubleshooting-01-deploy-svc-mismatch/stub-responses.json
    - cka-sim/tests/fixtures/phase-06/troubleshooting-01-deploy-svc-mismatch/expected-fail-score.txt
    - cka-sim/tests/fixtures/phase-06/troubleshooting-01-deploy-svc-mismatch/expected-pass-score.txt
  modified:
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/ref-solution.sh
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/metadata.yaml
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md
    - cka-sim/traps/catalog.yaml
decisions:
  - Registered imagepullbackoff-wrong-tag locally because metadata lint requires catalog entry and wave-mate append was absent in this worktree.
metrics:
  duration: unknown
  completed: 2026-05-13
  tasks: 2
  files_changed: 9
---

# Phase 06 Plan 03: Troubleshooting Q01 Retrofit Summary

Troubleshooting Q01 now covers Service endpoints mismatch plus sibling workload image-pull diagnosis using shared setup helpers and phase-06 fixtures.

## Completed Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Retrofit setup/grade/ref-solution | cdd77bb | setup.sh, grade.sh, ref-solution.sh |
| 2 | Metadata, prompt, fixtures | 7d3ce84 | metadata.yaml, question.md, fixture tree, traps/catalog.yaml |

## Changes

- `setup.sh` now sources `$CKA_SIM_ROOT/lib/setup.sh`, calls `ensure_lab_ns` and `wait_for_ns_active`, and removes the inline namespace polling loop.
- `setup.sh` keeps the intentional `web-svc` selector trap (`app: webserver`) and seeds `web-canary` with `nginx:1.27-alpine-typoXYZ`.
- `grade.sh` keeps the existing resource and endpoints oracle, keeps service label mismatch detection, and records `imagepullbackoff-wrong-tag` when canary pods report `ImagePullBackOff` or `ErrImagePull` through jsonpath.
- `ref-solution.sh` patches the Service selector to `app: web` and deletes `web-canary` so pass round-trip has no canary trap.
- `metadata.yaml` declares four traps and adds cross-pack prior-art reference to `cka-sim/packs/services-networking/02-service-core/`.
- `question.md` adds one symptom-only task line about a sibling workload failure without naming ImagePullBackOff or image tag root cause.
- Phase 6 fixture tree added with `stub-responses.json`, `SCORE: 2/3` fail score, and `SCORE: 3/3` pass score.

## Verification

- Passed: `bash -n` for setup, grade, reset, and ref-solution scripts.
- Passed: `py -3 -c "import json,sys; json.load(open(sys.argv[1]))" cka-sim/tests/fixtures/phase-06/troubleshooting-01-deploy-svc-mismatch/stub-responses.json`.
- Passed: `bash cka-sim/scripts/lint-traps.sh`.
- Passed: `bash cka-sim/scripts/lint-coverage.sh troubleshooting` with expected pre-P09 skip: `no coverage.yaml yet -- skipping`.
- Blocked by pre-existing unrelated issue: `bash cka-sim/scripts/lint-packs.sh` and `bash cka-sim/scripts/test.sh` fail because `cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh` contains banned `kubectl get | grep`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical catalog dependency] Registered `imagepullbackoff-wrong-tag`**
- **Found during:** Task 2 verification
- **Issue:** Plan depended on 06-02 wave-mate catalog append, but current worktree did not contain `imagepullbackoff-wrong-tag`, causing metadata lint failure.
- **Fix:** Added catalog entry with troubleshooting domain, error severity, remediation hint, and Kubernetes debug-pod reference.
- **Files modified:** `cka-sim/traps/catalog.yaml`
- **Commit:** 7d3ce84

## Deferred Issues

- Pre-existing lint failure outside this plan scope: `cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh` violates GRADE-02 banned `kubectl get | grep`. Not modified.

## Known Stubs

- `cka-sim/tests/fixtures/phase-06/troubleshooting-01-deploy-svc-mismatch/stub-responses.json`: intentional test fixture stub for future Phase 6 harness round-trip.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: trap-catalog | cka-sim/traps/catalog.yaml | New trap catalog entry added in this plan worktree to satisfy metadata resolution. |

## Self-Check: PASSED

- Found summary file.
- Found task commits: cdd77bb, 7d3ce84.
- Created fixture files present.
- No STATE.md or ROADMAP.md modifications made by this agent.
