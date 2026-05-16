---
phase: 04-storage-workloads-scheduling-packs
plan: 10
subsystem: packs
tags: [storage, pvc, deployment, volume-mount, read-only, kubectl-exec, marker-file]

# Dependency graph
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: shared cka-sim/lib/setup.sh helpers (Plan 04-01) + new storage trap catalog entries (Plan 04-02)
  - phase: 04-storage-workloads-scheduling-packs
    provides: storage-pvc-binding retrofit as reference shape (Plan 04-04)
provides:
  - Storage pack Q06 storage-pvc-mount-pod (6 files + 3 fixtures)
  - Marker-file exec probe pattern (kubectl exec deploy/... cat /data/marker) for PVC content verification
  - PVC-prewrite-via-writer-pod seeding idiom (restartPolicy OnFailure, waits for Succeeded)
  - Tracker coverage: mount-pvc-in-pod (primary), understand-pv-pvc (secondary)
affects: [04-16 manifest-catchup, future storage questions needing file-content probes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Writer-pod-pre-seed pattern for PVC content: setup creates ephemeral pod (restartPolicy=OnFailure) that writes marker, exits Succeeded; grader verifies via kubectl exec on candidate's Deployment"
    - "Marker-string behavioural assertion: grader tr -d whitespace + string-equality match against q06-marker sentinel"
    - "volumeName binding shortcut: PVC.spec.volumeName pins the target PV so bind is immediate, bypassing provisioner races during setup"

key-files:
  created:
    - cka-sim/packs/storage/06-pvc-mount-pod/metadata.yaml
    - cka-sim/packs/storage/06-pvc-mount-pod/question.md
    - cka-sim/packs/storage/06-pvc-mount-pod/setup.sh
    - cka-sim/packs/storage/06-pvc-mount-pod/grade.sh
    - cka-sim/packs/storage/06-pvc-mount-pod/reset.sh
    - cka-sim/packs/storage/06-pvc-mount-pod/ref-solution.sh
    - cka-sim/tests/fixtures/storage-06-pvc-mount-pod/stub-responses.json
    - cka-sim/tests/fixtures/storage-06-pvc-mount-pod/expected-fail-score.txt
    - cka-sim/tests/fixtures/storage-06-pvc-mount-pod/expected-pass-score.txt
  modified: []

key-decisions:
  - "Used PVC.spec.volumeName=q06-data-pv to pin the PVC to the seeded manual PV so Bound is deterministic before the writer pod launches (no provisioner in the lab cluster)"
  - "Writer pod uses restartPolicy=OnFailure with `echo + sync` so a successful write transitions to Succeeded and the pod does not restart"
  - "Collapsed the marker kubectl-exec onto a single line so the AC regex `kubectl exec.*cat /data/marker` matches as written"
  - "Seeded the hostPath PV WITH nodeAffinity (correctly pinned) since this question's trap is about candidate-side Deployment mistakes, not the seeded PV"

patterns-established:
  - "behavioural-exec-grader: kubectl exec deploy/<name> -- cat <path> | tr -d whitespace, then [[ == sentinel ]], incrementing CKA_SIM_GRADE_TOTAL manually outside the assert_* helpers"
  - "writer-pod-seed: setup.sh launches an ephemeral writer pod, waits for jsonpath Succeeded, then exits; grader (read-only) never touches the pre-written state"

requirements-completed: [PACK-01, PACK-06]

# Metrics
duration: ~15min
completed: 2026-05-11
---

# Phase 04 Plan 10: Storage Q06 pvc-mount-pod Summary

**Storage pack Q06 `storage-pvc-mount-pod`: candidate mounts a pre-seeded Bound PVC read-only in a Deployment; grader verifies via `kubectl exec ... cat /data/marker` behavioural probe.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-10T17:12:00Z
- **Completed:** 2026-05-10T17:27:00Z
- **Tasks:** 1
- **Files modified:** 9 (all created)

## Accomplishments

- Shipped full 6-file question shape for `storage-pvc-mount-pod` with exec-bit on all `.sh` files (chmod 755 in git index via `update-index --chmod=+x`).
- Setup seeds hostPath PV (with nodeAffinity, correctly pinned) + manual PVC `q06-data` + ephemeral writer pod that writes `/data/marker` with the sentinel `q06-marker` and exits Succeeded.
- Grader asserts Deployment existence, PVC `claimName=q06-data` on volumes[0], first `volumeMounts[0].readOnly=true`, and the behavioural marker exec probe (4 assertions total).
- Grader records `default-sa-used` trap if the candidate's pod inherits the default ServiceAccount (per RESEARCH §2.1 Q06 trap triad).
- Ref-solution lands a dedicated SA, `nginx:1.27`, resource requests (`cpu: 50m`, `memory: 64Mi`), and the read-only volumeMount; rollout status waits 120s.
- Metadata declares 3 traps (`hostpath-pv-without-nodeaffinity`, `default-sa-used`, `deployment-missing-requests`), `estimatedMinutes=7`, `verified_against="1.35"`, and 2 references (PV and Deployment docs).
- Round-trip fixture dir `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/` with `stub-responses.json` (the correct ref-solution Deployment), `expected-pass-score.txt` (`SCORE: 4/4`), and `expected-fail-score.txt` (`SCORE: 0/4`).

## Task Commits

Each task committed atomically:

1. **Task 1: 6 question files + 3 fixtures** - `d66bc98` (feat)

## Files Created

- `cka-sim/packs/storage/06-pvc-mount-pod/metadata.yaml` - id, domain, estimatedMinutes=7, 3 traps, 2 references
- `cka-sim/packs/storage/06-pvc-mount-pod/question.md` - candidate-facing brief (tasks + constraints + verify-yourself)
- `cka-sim/packs/storage/06-pvc-mount-pod/setup.sh` - ns + PV + PVC with `volumeName` binding + writer pod
- `cka-sim/packs/storage/06-pvc-mount-pod/grade.sh` - 4 assertions + default-sa-used detector
- `cka-sim/packs/storage/06-pvc-mount-pod/reset.sh` - async ns delete + cluster-scoped PV delete
- `cka-sim/packs/storage/06-pvc-mount-pod/ref-solution.sh` - dedicated SA + Deployment with read-only mount + rollout-status wait
- `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/stub-responses.json` - golden Deployment shape
- `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/expected-fail-score.txt` - no-candidate baseline (`SCORE: 0/4`)
- `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/expected-pass-score.txt` - ref-solution score (`SCORE: 4/4`)

## Decisions Made

- Pinned the PVC to the seeded PV via `spec.volumeName` to avoid any provisioner race. This is safe because the PV and PVC are both controlled by setup.sh and the candidate never recreates them.
- Chose `restartPolicy: OnFailure` for the writer pod so a successful `echo > /data/marker && sync` terminates cleanly (Succeeded). `Never` would also work, but OnFailure is the idiomatic choice for one-shot init jobs per k8s docs.
- Kept the setup PV correctly pinned (with `kubernetes.io/hostname` nodeAffinity) — the metadata `hostpath-pv-without-nodeaffinity` trap entry advertises the concept as a "concerns-md style" education item, not an active seeded bug here; the active behavioural bug surface is the candidate's Deployment (default SA + missing requests + wrong readOnly).
- Did NOT touch `cka-sim/packs/storage/manifest.yaml`. Plan 04-03 summary marks this as Plan 16's responsibility (Wave 4 manifest catch-up).

## Deviations from Plan

None — plan executed as written. The `kubectl exec` line was initially written across two lines via `\`-continuation; I single-lined it so the literal AC regex `kubectl exec.*cat /data/marker` matches in grade.sh. This is a surface edit to satisfy an explicit AC, not a design deviation.

## Issues Encountered

- `git add` on new files recorded mode 100644 despite filesystem +x bits; resolved via `git update-index --chmod=+x` on the four `.sh` files after staging. Final index shows 100755 on all four scripts. lint-packs.sh pass-D (executable-bit check) green.
- lint-coverage.sh reports "not in manifest.yaml" forward-reference errors for this and sibling Wave 3 question-ids. Expected per Plan 04-03 summary — manifest.yaml catch-up is Plan 16's job, not this plan's.

## Validation Results

- `bash cka-sim/scripts/lint-packs.sh` — PASS (18 checks).
- `bash cka-sim/scripts/test.sh` — PASS (all 29 unit cases).
- `grep -qE 'kubectl exec.*cat /data/marker' grade.sh` — match.
- `grep -qE 'readOnly' grade.sh` — match.
- `grep -qE 'readOnly: true' ref-solution.sh` — match.
- `grep -q 'serviceAccountName' ref-solution.sh` — match.
- `grep -q 'resources:' ref-solution.sh` — match.
- `! grep -qE 'kubectl[[:space:]]+(delete|create|apply|patch|edit|replace)' grade.sh` — no mutating verbs.
- `metadata.yaml`: `id: storage-pvc-mount-pod` + `domain: storage` + `estimatedMinutes: 7` + `verified_against: "1.35"` + 3 traps + 2 references.
- `bash -n` on all four `.sh` — syntax OK.

## Next Phase Readiness

- Storage pack has Q01 (pvc-binding, retrofit) + Q06 (pvc-mount-pod, this plan). Remaining Wave 3 storage questions (Q02-Q05) are in sibling plans 04-06..04-09 and Q03/Q04 in the parallel waves.
- Plan 16 (Wave 4) will update `cka-sim/packs/storage/manifest.yaml` to add `storage-pvc-mount-pod` (path: `06-pvc-mount-pod`), at which point `lint-coverage.sh` will go green for this tracker entry.

## Self-Check: PASSED

- File `cka-sim/packs/storage/06-pvc-mount-pod/metadata.yaml` — FOUND
- File `cka-sim/packs/storage/06-pvc-mount-pod/question.md` — FOUND
- File `cka-sim/packs/storage/06-pvc-mount-pod/setup.sh` — FOUND
- File `cka-sim/packs/storage/06-pvc-mount-pod/grade.sh` — FOUND
- File `cka-sim/packs/storage/06-pvc-mount-pod/reset.sh` — FOUND
- File `cka-sim/packs/storage/06-pvc-mount-pod/ref-solution.sh` — FOUND
- File `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/stub-responses.json` — FOUND
- File `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/expected-fail-score.txt` — FOUND
- File `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/expected-pass-score.txt` — FOUND
- Commit `d66bc98` — FOUND in `git log --oneline`

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-11*
