---
phase: 04-storage-workloads-scheduling-packs
plan: 09
subsystem: packs
tags: [bash, kubernetes, storage, pvc, storageclass, wait-for-first-consumer, wffc, pack-authoring]

requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/lib/setup.sh (Plan 01) — ensure_lab_ns + wait_for_ns_active + seed_pv_hostpath helpers
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/traps/catalog.yaml (Plan 02) — pvc-pending-wffc-unscheduled-consumer + pvc-wrong-storageclass + default-sa-used trap IDs
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/packs/storage/01-pvc-binding (Plan 04) — reference shape for storage pack authoring
provides:
  - Second storage question shipped (Wave 3, Q05) covering WaitForFirstConsumer volumeBindingMode
  - manifest.yaml registration (resolves coverage.yaml reference for understand-storageclass-dynamic tracker)
affects: [04-10-through-04-15-packs, 04-16-phase-verification]

tech-stack:
  added: []
  patterns:
    - "WFFC trap scenario: StorageClass with kubernetes.io/no-provisioner + manual hostPath PV pinned via nodeAffinity + Pending PVC waiting on pod scheduling"
    - "seed_pv_hostpath helper + kubectl patch to override storageClassName post-seed (helper emits storageClassName=manual; bind requires matching SC name)"
    - "ref-solution couples dedicated ServiceAccount + Pod so the reference run resolves the primary WFFC trap AND the reusable default-sa-used trap in one apply"

key-files:
  created:
    - cka-sim/packs/storage/05-wait-for-first-consumer/metadata.yaml
    - cka-sim/packs/storage/05-wait-for-first-consumer/question.md
    - cka-sim/packs/storage/05-wait-for-first-consumer/setup.sh
    - cka-sim/packs/storage/05-wait-for-first-consumer/grade.sh
    - cka-sim/packs/storage/05-wait-for-first-consumer/reset.sh
    - cka-sim/packs/storage/05-wait-for-first-consumer/ref-solution.sh
    - cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/stub-responses.json
    - cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/expected-pass-score.txt
    - cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/expected-fail-score.txt
  modified:
    - cka-sim/packs/storage/manifest.yaml

key-decisions:
  - "Override helper-default storageClassName via kubectl patch rather than extend seed_pv_hostpath signature: keeps Plan 01's helper surface frozen and avoids regressing the 01-pvc-binding pack"
  - "Bundle dedicated ServiceAccount into ref-solution.sh (not setup.sh) so the setup-seeded state still exhibits all three candidate traps and the reference run is the path to a perfect score"
  - "Behavioural-only grading (assert_pod_ready + assert_pvc_bound + assert_field_eq on claim ref) per GRADE-02; primary trap detected via status phase + pod name probe, not kubectl get | grep"

patterns-established:
  - "WFFC question shape: StorageClass (no-provisioner + WFFC) + manual PV with nodeAffinity + Pending PVC + candidate-authored consumer Pod"
  - "Per-question manifest.yaml registration is required for lint-coverage.sh to resolve coverage.yaml tracker references"

requirements-completed: [PACK-01, PACK-06]

duration: ~18min
completed: 2026-05-10
---

# Phase 4 Plan 09: Storage Q05 WaitForFirstConsumer Summary

**Storage Q05 `05-wait-for-first-consumer` ships: StorageClass `q05-wffc` + manual hostPath PV `q05-wffc-pv` + Pending PVC `q05-claim`; candidate writes Pod `q05-consumer` to trigger the WFFC binder; three behavioural assertions + three trap IDs covered.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-05-11T00:24:00Z
- **Completed:** 2026-05-11T00:29:00Z (approx, worktree wall-clock)
- **Tasks:** 1
- **Files created:** 9
- **Files modified:** 1

## Accomplishments

- 6 question files delivered under `cka-sim/packs/storage/05-wait-for-first-consumer/` (metadata, question, setup, grade, reset, ref-solution)
- 3 fixture files delivered under `cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/`
- `storage/manifest.yaml` now registers `storage-wait-for-first-consumer` so `lint-coverage.sh` resolves the `understand-storageclass-dynamic` tracker reference that Plan 03 pre-wired
- `bash cka-sim/scripts/test.sh` green (29/29 unit cases pass, lint-traps + lint-packs clean with 18 checks)
- `bash cka-sim/scripts/lint-packs.sh` green: all 5 passes (GRADE-02, mutating-verb, D-09 setup guard, 6-files + executable bits, metadata schema + trap registration)

## Task Commits

1. **Task 1: Ship Q05 files + fixtures** — `06988a6` (feat)
2. **Task 1 follow-up: Stamp +x on shell scripts** — `8a50b3c` (chore) — Windows `core.filemode=false` tracked initial commit as `100644`; `git update-index --chmod=+x` brings parity with the sibling `01-pvc-binding` pack (`100755`).

**Plan metadata:** [pending this SUMMARY commit]

## Files Created/Modified

### Created — pack

- `cka-sim/packs/storage/05-wait-for-first-consumer/metadata.yaml` — id `storage-wait-for-first-consumer`, domain `storage`, estimatedMinutes `7`, verified_against `"1.35"`, 3 trap IDs (primary + 2 reuse), 2 references (k8s-doc + prior-art-exercise).
- `cka-sim/packs/storage/05-wait-for-first-consumer/question.md` — prompt; explicit constraints forbid modifying the SC, PV, or PVC; mandates Pod name `q05-consumer` and `spec.volumes[0].persistentVolumeClaim.claimName`.
- `cka-sim/packs/storage/05-wait-for-first-consumer/setup.sh` — sources `lib/setup.sh`; ensures lab ns + 120s Active wait; applies StorageClass `q05-wffc` (`kubernetes.io/no-provisioner`, WFFC, Retain); calls `seed_pv_hostpath q05-wffc-pv 1Gi ReadWriteOnce Retain /tmp/q05-wffc-pv kubernetes.io/hostname`; patches PV `storageClassName` to match SC; applies Pending PVC `q05-claim` (500Mi, RWO, SC `q05-wffc`).
- `cka-sim/packs/storage/05-wait-for-first-consumer/grade.sh` — sources `lib/grade.sh` + `lib/traps.sh`; `kubectl wait` guard for pod Ready (60s); behavioural assertions `assert_pod_ready`, `assert_pvc_bound`, `assert_field_eq pod q05-consumer '{.spec.volumes[0].persistentVolumeClaim.claimName}' 'q05-claim' -n $CKA_SIM_LAB_NS`; primary trap via PVC-phase-`Pending` + pod-absent probe; secondary trap via `cka_sim::trap::detect_default_sa_used`; finalizer `emit_result`.
- `cka-sim/packs/storage/05-wait-for-first-consumer/reset.sh` — async ns delete (runner-owns-cleanup contract) + cluster-scoped PV + SC delete (`q<NN>-` prefix per TRIP-03).
- `cka-sim/packs/storage/05-wait-for-first-consumer/ref-solution.sh` — dedicated ServiceAccount `q05-consumer-sa` with `automountServiceAccountToken: false`, Pod `q05-consumer` (busybox:1.36, sleep 3600, `/data` volume mount); `kubectl wait` PVC Bound then pod Ready.

### Created — fixtures

- `cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/stub-responses.json` — Pending PVC doc with `storageClassName: q05-wffc` (500Mi RWO).
- `cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/expected-pass-score.txt` — `SCORE: 3/3` (ref-solution path).
- `cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/expected-fail-score.txt` — `SCORE: 0/3` (seed-only path: no Pod, PVC stays Pending, two traps fire).

### Modified

- `cka-sim/packs/storage/manifest.yaml` — appended `storage-wait-for-first-consumer` entry pointing at `05-wait-for-first-consumer` with `estimatedMinutes: 7`. Resolves the pre-wired `understand-storageclass-dynamic` tracker reference.

## Decisions Made

- **Override helper-default `storageClassName` via `kubectl patch --type=merge`:** `seed_pv_hostpath` (Plan 01) emits PVs with a hard-coded `storageClassName: manual`. Extending the helper signature for this single use would reopen Plan 01 and risk regressing `01-pvc-binding`. A one-line patch after `seed_pv_hostpath` returns keeps the helper frozen and the override intent explicit in the setup file.
- **Dedicated ServiceAccount in ref-solution.sh, not setup.sh:** the setup must reproduce the seed state for every trap — including `default-sa-used`. Placing the SA in setup would silently fix that trap at boot, meaning a candidate who forgot SA hygiene would never see it fire. Putting the SA in the reference path is the canonical GRADE-06 round-trip pattern (`setup && ref-solution && grade → 3/3 + 0 traps`).
- **Behavioural assertions only:** three grader assertions all use `lib/grade.sh` helpers (`assert_pod_ready`, `assert_pvc_bound`, `assert_field_eq` on the volume claim ref). No `kubectl get | grep`, no `-A`, no mutating verbs. Primary WFFC trap detected by reading PVC phase and probing for Pod existence; secondary trap via the catalog's `detect_default_sa_used` detector. GRADE-02 + mutating-verb lint pass A/B clean.
- **Set +x via `git update-index --chmod=+x`:** filesystem `chmod +x` applied locally but Windows `core.filemode=false` recorded `100644` in the tree. Follow-up `chore` commit fixes the mode to `100755` to match the sibling `01-pvc-binding` pack and satisfy lint-packs pass D on unix runners.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Executable bit missing on shell scripts in recorded tree**
- **Found during:** Post-commit `git ls-files -s` audit
- **Issue:** `chmod +x` worked on the Windows filesystem but git recorded `100644` (no executable bit) because `core.filemode=false` on this repo/platform. lint-packs pass D (`[[ ! -x "$q_dir/$f" ]]`) looks at filesystem mode and passed locally, but a unix runner cloning the repo would see non-executable scripts and fail the same lint.
- **Fix:** `git update-index --chmod=+x` on all four scripts, follow-up `chore` commit `8a50b3c`.
- **Files modified:** `cka-sim/packs/storage/05-wait-for-first-consumer/{setup,grade,reset,ref-solution}.sh` (mode `100644 → 100755`).
- **Commit:** `8a50b3c`

**2. [Rule 3 - Blocking issue] Missing manifest.yaml registration for new question**
- **Found during:** Plan reading phase (coverage.yaml already pre-wired in Plan 03 references `storage-wait-for-first-consumer`)
- **Issue:** The plan's files_modified list did not mention `cka-sim/packs/storage/manifest.yaml`, but the coverage.yaml tracker `understand-storageclass-dynamic` already lists `storage-wait-for-first-consumer` under its `questions:` block. Leaving the manifest unchanged would make `lint-coverage.sh` emit a new `question-id '...' referenced in coverage.yaml is not in manifest.yaml` error for this pack (while Wave 3 as a whole still has other pre-existing coverage errors for unshipped packs, adding a new one for a question this plan *did* ship is a self-inflicted regression).
- **Fix:** Appended `storage-wait-for-first-consumer` entry to `cka-sim/packs/storage/manifest.yaml`.
- **Files modified:** `cka-sim/packs/storage/manifest.yaml` (+3 lines)
- **Commit:** `06988a6` (folded into the primary task commit — this is the authoritative registration step).

### Deferred (out of scope per deviation-rules)

- `lint-coverage.sh` still reports 14 pre-existing coverage errors for question-ids that other Wave 3 plans will ship (`storage-pvc-mount-pod`, `storage-storageclass-dynamic`, `storage-access-modes-reclaim`, `storage-csi-volumesnapshot`, plus 7 workloads-scheduling entries). These are NOT gated by `test.sh` (which only runs `lint-traps` + `lint-packs` + the unit cases) and will resolve as each Wave 3 plan registers its question in the respective manifest.yaml. Out of scope for Plan 09 per the "only auto-fix issues directly caused by the current task" boundary. No `deferred-items.md` update needed — these are pre-existing, tracked by the Plan 03 wiring itself.

## Issues Encountered

- None beyond the two auto-fixes documented above.

## User Setup Required

- None. The pack is schema-complete and lint-clean; live-cluster verification belongs in Plan 04-16 (phase VERIFICATION.md) per the Phase 3 model.

## Next Phase Readiness

- Q05 is the second question in the Storage pack and the second of two questions covering the `understand-storageclass-dynamic` tracker slug.
- Wave 3 continues with Plans 10-15 (remaining storage + workloads-scheduling questions). This pack establishes the WFFC scenario shape (SC + manual PV + Pending PVC + candidate-authored consumer Pod) that later packs can reuse for other volumeBindingMode or storage-class-plumbing questions.
- The manifest.yaml registration pattern demonstrated here must be repeated by every subsequent pack-shipping plan so `lint-coverage.sh` converges to zero by end of Wave 3.

## Self-Check: PASSED

- FOUND: cka-sim/packs/storage/05-wait-for-first-consumer/metadata.yaml
- FOUND: cka-sim/packs/storage/05-wait-for-first-consumer/question.md
- FOUND: cka-sim/packs/storage/05-wait-for-first-consumer/setup.sh (mode 100755)
- FOUND: cka-sim/packs/storage/05-wait-for-first-consumer/grade.sh (mode 100755)
- FOUND: cka-sim/packs/storage/05-wait-for-first-consumer/reset.sh (mode 100755)
- FOUND: cka-sim/packs/storage/05-wait-for-first-consumer/ref-solution.sh (mode 100755)
- FOUND: cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/stub-responses.json
- FOUND: cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/expected-pass-score.txt
- FOUND: cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/expected-fail-score.txt
- FOUND commit: 06988a6 (feat(04-09): add storage/05-wait-for-first-consumer pack)
- FOUND commit: 8a50b3c (chore(04-09): set +x bit on storage-05 shell scripts)
- VERIFIED: `bash cka-sim/scripts/test.sh` → 29/29 unit cases pass, lint-traps + lint-packs clean
- VERIFIED: `bash cka-sim/scripts/lint-packs.sh` → 18 checks, 0 errors
- VERIFIED: `bash -n` passes on all four shell scripts
- VERIFIED: `grep -q 'WaitForFirstConsumer' cka-sim/packs/storage/05-wait-for-first-consumer/setup.sh`
- VERIFIED: `grep -q 'cka_sim::setup::seed_pv_hostpath' cka-sim/packs/storage/05-wait-for-first-consumer/setup.sh`
- VERIFIED: `grep -q 'pvc-pending-wffc-unscheduled-consumer' cka-sim/packs/storage/05-wait-for-first-consumer/grade.sh`
- VERIFIED: ref-solution contains both `kind: ServiceAccount` and `kind: Pod`
- VERIFIED: grade.sh contains no `kubectl get | grep`, no `kubectl get -A`, no mutating verbs

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
