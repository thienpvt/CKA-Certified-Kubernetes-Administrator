---
phase: 04-storage-workloads-scheduling-packs
plan: 08
subsystem: packs-storage
tags: [bash, kubernetes, storage, csi, volumesnapshot, hostpath-csi, external-snapshotter, cg-01, pack-01]

requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/lib/setup.sh (Plan 01) — ensure_lab_ns + wait_for_ns_active helpers
  - phase: 04-storage-workloads-scheduling-packs
    provides: traps catalog entries csi-snapshot-wrong-driver, pvc-pending-wffc-unscheduled-consumer (Plan 02)
  - phase: 04-storage-workloads-scheduling-packs
    provides: trap catalog entry pvc-wrong-storageclass (Phase 3 reuse)
  - phase: 03-runtime-contract-drill-mode
    provides: lib/grade.sh (assert_resource_exists, assert_field_eq, record_trap, emit_result)
provides:
  - PACK-01 CG-01 closure — CSI/VolumeSnapshot question shipped
  - Tracker slug `csi-basics` covered by storage-csi-volumesnapshot
  - First question in the repo that self-installs an external CSI driver (pinned v1.14.0)
  - Proven idempotent install + refcount uninstall pattern reusable by future CSI questions
affects: [04-09-storage-wait-for-first-consumer, 04-10-storage-pvc-mount-pod, 04-15-lint-coverage, 04-16-verification]

tech-stack:
  added:
    - "kubernetes-csi/csi-driver-host-path v1.14.0 (pinned kustomize ref=v1.14.0)"
    - "kubernetes-csi/external-snapshotter v7.0.2 (pinned raw-URL CRDs + snapshot-controller)"
  patterns:
    - "idempotent install sentinels: api-resources for snapshot.storage.k8s.io, namespace csi-hostpath existence"
    - "refcount uninstall via cka-sim/uses=csi-hostpath label + --field-selector metadata.namespace!=<self>"
    - "behavioural GRADE-02 assertion via kubectl wait --for=jsonpath readyToUse=true (no mutating verb in grader)"

key-files:
  created:
    - cka-sim/packs/storage/04-csi-volumesnapshot/metadata.yaml
    - cka-sim/packs/storage/04-csi-volumesnapshot/question.md
    - cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh
    - cka-sim/packs/storage/04-csi-volumesnapshot/grade.sh
    - cka-sim/packs/storage/04-csi-volumesnapshot/reset.sh
    - cka-sim/packs/storage/04-csi-volumesnapshot/ref-solution.sh
    - cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/stub-responses.json
    - cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/expected-fail-score.txt
    - cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/expected-pass-score.txt
  modified: []

key-decisions:
  - "Install sentinels: api-resources lookup for snapshot.storage.k8s.io and `kubectl get namespace csi-hostpath` — re-running setup on a cluster that already has the driver is a no-op (TRIP-02 idempotency)"
  - "Refcount uninstall: reset.sh tears the driver down only when no OTHER lab ns still has a PVC labelled cka-sim/uses=csi-hostpath; the excluding `--field-selector metadata.namespace!=<ns>` stops self-counting"
  - "Snapshot CRDs are left installed on reset — removing them is destructive across co-tenant drills (Helm charts, other labs, user workloads) per RESEARCH §6.1"
  - "Third trap is pvc-wrong-storageclass (detected by reading `.spec.storageClassName != csi-hostpath-sc`) — the plan allowed either reuse path and this is the simplest detector that does not false-positive on the happy path"
  - "Grader uses `kubectl wait --for=jsonpath` for the behavioural GRADE-02 wait, not `kubectl patch/apply` (which lint-packs Pass B rejects)"

patterns-established:
  - "CSI question shape: setup installs driver behind sentinels → seeds PVC with cka-sim/uses=<driver> label → reset refcounts the label before teardown"
  - "Labelling PVCs with `cka-sim/uses: <driver-name>` to coordinate driver lifecycle across independent lab namespaces"

requirements-completed: [PACK-01, PACK-06]

duration: ~25min
completed: 2026-05-10
---

# Phase 4 Plan 08: Storage Q04 CSI VolumeSnapshot Summary

**CSI + VolumeSnapshot question (CG-01) self-installs hostpath-csi v1.14.0 + external-snapshotter v7.0.2 behind idempotent sentinels, seeds a WFFC PVC + marker writer pod, grades via `kubectl wait --for=jsonpath readyToUse=true`, and refcounts the driver on reset via `cka-sim/uses=csi-hostpath` labels.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-10T17:00:00Z
- **Completed:** 2026-05-10T17:25:00Z
- **Tasks:** 2
- **Files created:** 9 (6 question files + 3 fixtures)

## Accomplishments

- Storage Q04 shipped end-to-end (PACK-01 CG-01 mandate + Tracker slug `csi-basics` closed)
- First CSI-backed question in the repo. Install is fully self-contained: external-snapshotter v7.0.2 + hostpath-csi v1.14.0 come up from upstream manifests on first run, skip silently on subsequent runs
- Refcount uninstall pattern: the driver is torn down only when no other lab namespace still has a PVC labelled `cka-sim/uses=csi-hostpath`, so parallel or overlapping drills can share one driver install safely
- Grader is fully behavioural per GRADE-02 — the only waiting verb is `kubectl wait --for=jsonpath='{.status.readyToUse}'=true`, which the mutating-verb lint accepts
- Three trap detectors wired (csi-snapshot-wrong-driver, pvc-wrong-storageclass, pvc-pending-wffc-unscheduled-consumer)
- `bash cka-sim/scripts/test.sh` green: 18 pack-lint checks + 29 unit cases, zero failures

## Task Commits

1. **Task 1: metadata.yaml + question.md** — `9a5a512` (feat)
2. **Task 2: setup.sh + grade.sh + reset.sh + ref-solution.sh + fixtures** — `5d10d9f` (feat)

**Plan metadata:** [pending this SUMMARY commit]

## Files Created/Modified

- `cka-sim/packs/storage/04-csi-volumesnapshot/metadata.yaml` — id=storage-csi-volumesnapshot, domain=storage, estimatedMinutes=9, verified_against=1.35, 3 traps, 2 references
- `cka-sim/packs/storage/04-csi-volumesnapshot/question.md` — scenario prompt, no driver-name or snapshot-class-name spoiler
- `cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh` — installs external-snapshotter v7.0.2 CRDs + snapshot-controller (gated on api-resources), hostpath-csi v1.14.0 (gated on `kubectl get namespace csi-hostpath`), then applies VolumeSnapshotClass + StorageClass + labelled PVC + writer pod
- `cka-sim/packs/storage/04-csi-volumesnapshot/grade.sh` — 3 assertions (resource exists, source PVC name, readyToUse=true), 3 trap detectors, read-only (no mutating verbs)
- `cka-sim/packs/storage/04-csi-volumesnapshot/reset.sh` — async ns delete + refcounted driver teardown via `cka-sim/uses=csi-hostpath` label with self-exclusion
- `cka-sim/packs/storage/04-csi-volumesnapshot/ref-solution.sh` — creates the VolumeSnapshot + waits for readyToUse=true (120s timeout aligned with upstream CI)
- `cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/stub-responses.json` — VolumeSnapshot stub for test.sh
- `cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/expected-fail-score.txt` — `SCORE: 0/3`
- `cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/expected-pass-score.txt` — `SCORE: 3/3`

## Decisions Made

- **Install sentinels not kubectl status polling.** The API-resources probe for `snapshot.storage.k8s.io/volumesnapshots` is the cheapest idempotency check (single HTTP call) and the canonical one the kubernetes-csi community recommends. Namespace existence for `csi-hostpath` is the driver's own canonical namespace; using its presence as a sentinel avoids coupling to a particular Deployment name or label that might drift between driver versions.
- **Refcount uses PVC labels, not a custom annotation on the driver namespace.** PVCs are the actual consumers; if any lab still has one labelled `cka-sim/uses=csi-hostpath`, the driver must stay. Self-exclusion via `--field-selector metadata.namespace!=<self>` stops the namespace being torn down from counting its own PVCs against itself.
- **Snapshot CRDs are intentionally left installed on reset.** Per RESEARCH §6.1 and §9 risk table: ripping CRDs out is destructive for any Helm chart, other drill, or user workload that already depends on them. Reset only removes the StorageClass, VolumeSnapshotClass, and the driver namespace.
- **Third trap is `pvc-wrong-storageclass` (not `pv-accessmodes-mismatch`).** The plan accepted any reused storage trap; `pvc-wrong-storageclass` has a clean detector path (read `.spec.storageClassName`) that cannot false-positive on the happy path because setup.sh fixes the PVC's SC name to `csi-hostpath-sc` itself. Adding it pushes traps[] to 3 without needing a custom PV accessModes mismatch setup.
- **Behavioural wait lives in the grader, not only in ref-solution.** `kubectl wait --for=jsonpath='{.status.readyToUse}'=true` is read-only and passes lint-packs Pass B (mutating-verb rejection). Gives the snapshot up to 90s to settle before the grader takes its reading — absorbs the async ingress time the snapshot controller needs.

## Deviations from Plan

None — plan executed exactly as written. The one small interpretive choice (third trap id) was within the plan's explicit latitude (`traps: [csi-snapshot-wrong-driver, pvc-wrong-storageclass, pvc-pending-wffc-unscheduled-consumer]` is the literal list the plan mandated).

## Issues Encountered

None. No auth gates hit. No Rule 1-3 auto-fixes needed. No Rule 4 architectural questions.

## Known Stubs

None. All 9 files contain production-quality content. No placeholders, no TODOs, no hardcoded empty values reaching user-facing output.

## Authentication Gates

None. All work was local file authoring + git commits.

## Pinned Versions

| Component | Version | Install path |
|---|---|---|
| external-snapshotter CRDs | v7.0.2 | `https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/...` (3 CRDs) |
| snapshot-controller | v7.0.2 | `https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/deploy/kubernetes/snapshot-controller/{rbac,setup}-snapshot-controller.yaml` |
| hostpath-csi driver | v1.14.0 | `kubectl apply -k 'https://github.com/kubernetes-csi/csi-driver-host-path/deploy/kubernetes-latest/hostpath?ref=v1.14.0'` |
| verified-against k8s | 1.35 | RESEARCH §6.1 pin |

All pins match the 04-RESEARCH.md §6.1 and §9 risk-table guidance.

## Verification (Live 1+2 cluster)

The static gates (lint-packs + test.sh) are green here. Live 1+2 cluster round-trip verification for this question belongs in Phase 04 Plan 16 (VERIFICATION). Items that plan must confirm:

- `bash setup.sh` on a fresh 1+2 kubeadm cluster completes within ~3 min (driver pod Ready) and produces a Bound PVC after the writer pod is scheduled.
- `bash ref-solution.sh` transitions `volumesnapshot/q04-app-snapshot` to `readyToUse=true` within 60s.
- `bash grade.sh` prints `SCORE: 3/3` and no `Trap N:` lines post-ref-solution.
- A second run of `bash setup.sh` (idempotency) performs zero driver-install work: both sentinels (`api-resources` and `kubectl get namespace csi-hostpath`) succeed, so the two `if` blocks skip.
- `bash reset.sh` when another lab ns still holds a `cka-sim/uses=csi-hostpath` PVC tears down only the lab namespace; the driver remains. When this is the last such PVC, the driver is torn down too.

## Next Phase Readiness

- CSI pattern is now proven; later CSI-adjacent plans (04-09 WaitForFirstConsumer, 04-10 mount PVC in Pod) can reuse the install-once, refcount-uninstall pattern.
- Coverage lint (Plan 04-15) can now reference `storage-csi-volumesnapshot` against the `csi-basics` Tracker slug in `cka-sim/packs/storage/coverage.yaml`.
- `cka-sim/uses=<driver>` labelling is a new convention — document in the Phase 4 retrospective so future CSI authors (e.g. a later CephFS question) adopt the same key rather than inventing a parallel one.

## Self-Check: PASSED

- FOUND: cka-sim/packs/storage/04-csi-volumesnapshot/metadata.yaml
- FOUND: cka-sim/packs/storage/04-csi-volumesnapshot/question.md
- FOUND: cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh (chmod +x, bash -n clean)
- FOUND: cka-sim/packs/storage/04-csi-volumesnapshot/grade.sh (chmod +x, bash -n clean)
- FOUND: cka-sim/packs/storage/04-csi-volumesnapshot/reset.sh (chmod +x, bash -n clean)
- FOUND: cka-sim/packs/storage/04-csi-volumesnapshot/ref-solution.sh (chmod +x, bash -n clean)
- FOUND: cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/stub-responses.json
- FOUND: cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/expected-fail-score.txt
- FOUND: cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/expected-pass-score.txt
- FOUND commit: 9a5a512 (feat(04-08): add storage/04-csi-volumesnapshot metadata + question)
- FOUND commit: 5d10d9f (feat(04-08): ship storage/04-csi-volumesnapshot CSI + VolumeSnapshot (CG-01))
- VERIFIED: `bash cka-sim/scripts/lint-packs.sh` green (18 checks)
- VERIFIED: `bash cka-sim/scripts/test.sh` green (29/29 unit cases)
- VERIFIED: setup.sh contains 5 `external-snapshotter/v7.0.2` references + `ref=v1.14.0` hostpath-csi pin + both install sentinels
- VERIFIED: grade.sh uses `kubectl wait --for=jsonpath readyToUse=true`, emits `emit_result`, no mutating verbs (lint-packs Pass B green)
- VERIFIED: reset.sh refcounts via `cka-sim/uses=csi-hostpath` label with self-exclusion
- VERIFIED: no `csi-hostpath-snapshotclass` or `hostpath.csi.k8s.io` string spoilers in question.md

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
