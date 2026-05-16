---
phase: 04-storage-workloads-scheduling-packs
plan: 03
status: complete
completed: 2026-05-10
subsystem: cka-sim/scripts/lint-coverage
tags: [coverage-matrix, lint, pack-07, pure-bash-yaml, tracker-completeness]
requires:
  - cka-sim/scripts/lint-packs.sh (structural template: CKA_SIM_LINT_PACKS_DIR override + err/warn counters + exit semantics)
  - cka-sim/scripts/lint-traps.sh (pure-bash YAML parser reference — state machine on 2/4/6-space indent)
  - cka-sim/tests/lib/assert.sh (expect_eq, expect_contains for unit cases)
  - cka-sim/tests/run.sh + cka-sim/scripts/test.sh (harness that discovers the 2 new cases)
provides:
  - PACK-07 coverage-matrix lint for per-pack coverage.yaml files
  - Storage coverage matrix (6 Tracker slugs -> 5 unique question-ids; access-modes-reclaim covers 2 trackers)
  - Workloads-Scheduling coverage matrix (9 Tracker slugs -> 8 unique question-ids; nodeselector-affinity-taints covers 2 trackers)
  - 4 fixture packs covering the 4 lint outcome paths (good / missing-question / empty-tracker / orphan)
  - 2 unit cases exercising schema + completeness checks
affects:
  - Plans 04-04..04-15 (Wave 3 authors the forward-referenced question-ids)
  - Plan 04-16 (wires lint-coverage.sh into scripts/validate-local.sh + .github/workflows/validate.yml after Wave 3 lands)
tech-stack:
  added: []
  patterns: [pure-bash-yaml-block-list-parser, fixture-driven-lint-unit-test, forward-reference-coverage-file]
key-files:
  created:
    - cka-sim/packs/storage/coverage.yaml
    - cka-sim/packs/workloads-scheduling/coverage.yaml
    - cka-sim/scripts/lint-coverage.sh
    - cka-sim/tests/cases/lint_coverage_schema.sh
    - cka-sim/tests/cases/lint_coverage_completeness.sh
    - cka-sim/tests/fixtures/lint-coverage/good/manifest.yaml
    - cka-sim/tests/fixtures/lint-coverage/good/coverage.yaml
    - cka-sim/tests/fixtures/lint-coverage/missing-question/manifest.yaml
    - cka-sim/tests/fixtures/lint-coverage/missing-question/coverage.yaml
    - cka-sim/tests/fixtures/lint-coverage/empty-tracker/manifest.yaml
    - cka-sim/tests/fixtures/lint-coverage/empty-tracker/coverage.yaml
    - cka-sim/tests/fixtures/lint-coverage/orphan/manifest.yaml
    - cka-sim/tests/fixtures/lint-coverage/orphan/coverage.yaml
  modified: []
key-decisions:
  - "coverage.yaml question-ids intentionally forward-reference ids that Plans 04-04..04-15 (Wave 3) will create in manifest.yaml. Running lint-coverage.sh against the live storage/workloads-scheduling packs will therefore report 'question-id not in manifest.yaml' errors until Plan 16 lands. The 2 unit cases use self-contained fixture packs, so test.sh stays green."
  - "Orphan questions (declared in manifest but not referenced in any tracker slug) produce a warning, not an error. This lets Wave 3 scaffold questions without requiring per-task coverage.yaml edits — the orphan warning simply prompts a cleanup pass in Plan 16."
  - "Lint uses pure bash per D-04 — no python, no yq. Mirrors the lint-traps.sh state-machine pattern on 2/4/6-space indent. Flow-list syntax (`questions: []`) is deliberately not supported by the parser, so empty-tracker fixtures emit the intended 'empty questions list' error."
  - "CKA_SIM_LINT_PACKS_DIR environment override reused from lint-packs.sh so unit cases point at the fixture tree without mocking the real packs dir."
  - "lint-coverage.sh is NOT yet wired into test.sh or validate-local.sh — Plan 16 adds it after Wave 3 populates both manifests. Including it now would turn test.sh red for the remainder of Phase 4."
patterns-established:
  - "Forward-reference coverage files: coverage.yaml may list question-ids that do not yet exist in manifest.yaml; lint tolerates this only when invoked against fixture packs, not when wired into CI. CI integration happens in the phase's terminal plan (Plan 16)."
  - "Fixture-driven lint unit test: each lint rule gets one fixture per outcome (good + 1 fixture per error path + 1 fixture per warning path). Unit cases invoke the lint with CKA_SIM_LINT_PACKS_DIR pointing at the fixture dir and assert exit code + stderr markers via expect_eq/expect_contains."
requirements-completed: [PACK-07]
metrics:
  duration_minutes: 18
  completed_date: 2026-05-10
  tasks_completed: 2
  files_created: 13
  commits: 2
---

# Phase 4 Plan 3: Coverage-Matrix Lint Summary

**PACK-07 coverage-matrix lint — per-pack coverage.yaml mapping Tracker checkboxes to question-ids, enforced by a pure-bash linter with 4-path fixture coverage (good / missing-ref / empty-tracker / orphan).**

## Performance

- **Duration:** 18 min
- **Started:** 2026-05-10T16:38Z
- **Completed:** 2026-05-10T16:56Z
- **Tasks:** 2
- **Files created:** 13
- **Files modified:** 0

## Accomplishments

- Shipped `cka-sim/scripts/lint-coverage.sh` — pure-bash coverage-matrix linter modelled on `lint-packs.sh`. Three checks: (1) every tracker slug has ≥1 question, (2) every referenced question-id exists in `manifest.yaml`, (3) orphan manifest questions produce a warning (non-fatal).
- Authored two domain coverage files mapping the v1.35 Study Progress Tracker checkboxes to the question-ids Plans 04-04..04-15 will create.
  - **Storage** — 6 Tracker slugs → 5 unique question-ids (`storage-access-modes-reclaim` covers both `know-access-modes` and `know-reclaim-policies`).
  - **Workloads & Scheduling** — 9 Tracker slugs → 8 unique question-ids (`workloads-nodeselector-affinity-taints` covers both `nodeselector-node-affinity` and `taints-tolerations`).
- Shipped 4 fixture packs (`good`, `missing-question`, `empty-tracker`, `orphan`) and 2 unit cases (`lint_coverage_schema.sh`, `lint_coverage_completeness.sh`). Suite grows from 23 to 25 cases, all green.

## Task Commits

1. **Task 1: Create storage + workloads-scheduling coverage.yaml** — `93bed96` (feat)
2. **Task 2: Implement lint-coverage.sh + 2 unit cases + 4 fixture packs** — `b5f505a` (feat)

(No plan-level metadata commit — the orchestrator owns `.planning/STATE.md` and `.planning/ROADMAP.md` updates per the execution prompt.)

## Files Created

- `cka-sim/packs/storage/coverage.yaml` — Storage domain Tracker→question map (6 slugs, 7 refs).
- `cka-sim/packs/workloads-scheduling/coverage.yaml` — Workloads domain Tracker→question map (9 slugs, 9 refs).
- `cka-sim/scripts/lint-coverage.sh` — PACK-07 lint (pure bash, D-04 compliant). Executable.
- `cka-sim/tests/cases/lint_coverage_schema.sh` — good + orphan exit-0 path.
- `cka-sim/tests/cases/lint_coverage_completeness.sh` — missing-question + empty-tracker exit-1 path.
- `cka-sim/tests/fixtures/lint-coverage/{good,missing-question,empty-tracker,orphan}/{manifest,coverage}.yaml` — 8 fixture files, one pair per outcome.

## Lint Algorithm (reference)

```
parse manifest.yaml -> set MANIFEST_IDS (newline-separated question-ids)
parse coverage.yaml -> set COVERAGE_TRACKERS (slugs) and COVERAGE_REFS (slug=qid pairs)

check 1: coverage has any tracker entries -> else error "no tracker entries"
check 2: each slug in COVERAGE_TRACKERS has >=1 ref -> else error "empty questions list"
check 3: each qid in COVERAGE_REFS exists in MANIFEST_IDS -> else error "not in manifest.yaml"
check 4: each qid in MANIFEST_IDS is referenced at least once -> else warning "orphan"
```

Exit codes: 0 = all OK (warnings allowed), 1 = any error from checks 1-3.

## Verification

- `bash cka-sim/scripts/test.sh` — exit 0. Step 1 (catalog lint) green; step 2 (pack lint) green; step 3 runs all 25 unit cases including the 2 new `lint_coverage_*` cases.
- `bash -n cka-sim/scripts/lint-coverage.sh` — syntax clean.
- Direct fixture round-trip:
  - `good` → exit 0, "coverage schema OK"
  - `orphan` → exit 0, "demo-q2 declared in manifest.yaml but not referenced in coverage.yaml (orphan)"
  - `missing-question` → exit 1, "question-id 'demo-q2' referenced in coverage.yaml is not in manifest.yaml"
  - `empty-tracker` → exit 1, "tracker slug 'csi-basics' has empty questions list"
- Direct live-pack check: `bash cka-sim/scripts/lint-coverage.sh storage` exits 1 with 7 "not in manifest.yaml" errors for `storage-pvc-mount-pod`, `storage-storageclass-dynamic`, `storage-wait-for-first-consumer`, `storage-access-modes-reclaim` (×2), `storage-csi-volumesnapshot`, and `storage-pvc-mount-pod` (duplicate under a second tracker). **This is the intended outcome for Wave 1** — see Future Work.

## Storage Tracker Coverage

| Tracker slug | Label | Questions | Plans providing |
|---|---|---|---|
| `understand-pv-pvc` | Understand PersistentVolume and PersistentVolumeClaim | `storage-pvc-binding`, `storage-pvc-mount-pod` | Phase 3 (retrofit via Plan 04-04) + Plan 04-10 |
| `understand-storageclass-dynamic` | Understand StorageClass and dynamic provisioning | `storage-storageclass-dynamic`, `storage-wait-for-first-consumer` | Plans 04-06 + 04-09 |
| `know-access-modes` | Know access modes (RWO, ROX, RWX, RWOP) | `storage-access-modes-reclaim` | Plan 04-07 |
| `know-reclaim-policies` | Know reclaim policies (Retain, Delete) | `storage-access-modes-reclaim` | Plan 04-07 (shared with access-modes) |
| `csi-basics` | CSI driver basics and troubleshooting | `storage-csi-volumesnapshot` | Plan 04-08 |
| `mount-pvc-in-pod` | Mount PVC in a Pod | `storage-pvc-mount-pod` | Plan 04-10 |

## Workloads & Scheduling Tracker Coverage

| Tracker slug | Label | Questions | Plans providing |
|---|---|---|---|
| `deployment-requests-limits` | Deployments with resource requests and limits | `workloads-deployment-requests` | Phase 3 (retrofit via Plan 04-04) |
| `rolling-update-rollback` | Rolling update and rollback | `workloads-rolling-update-rollback` | Plan 04-11 |
| `configmap-secret-env-volume` | ConfigMaps and Secrets (env and volume) | `workloads-configmap-secret-env-volume` | Plan 04-12 |
| `hpa-autoscaling-v2` | HPA (autoscaling/v2) | `workloads-hpa-metrics-server` | Plan 04-13 |
| `daemonset` | DaemonSet | `workloads-daemonset` | Plan 04-13 |
| `static-pods` | Static pods | `workloads-static-pod` | Plan 04-14 |
| `native-sidecar` | Native sidecar containers (restartPolicy: Always on initContainer) | `workloads-native-sidecar` | Plan 04-14 |
| `nodeselector-node-affinity` | nodeSelector and node affinity | `workloads-nodeselector-affinity-taints` | Plan 04-15 |
| `taints-tolerations` | Taints and tolerations | `workloads-nodeselector-affinity-taints` | Plan 04-15 (shared with nodeselector) |

_(Plan-number mapping derived from 04-CONTEXT.md Wave 3 enumeration; adjust if Plans 04-06..04-15 shift ordering.)_

## Decisions Made

See `key-decisions` frontmatter above. In plain terms:

1. **Forward references are intentional.** coverage.yaml files name question-ids Wave 3 will ship. Lint passes on fixtures but fails on live packs today — by design. Plan 16 integrates lint-coverage into `validate-local.sh` only after Wave 3 closes so CI never goes red in the interim.
2. **Orphan = warning, not error.** Lets Wave 3 scaffold without per-task coverage edits. Plan 16 sweeps any surviving orphans before CI wiring.
3. **Pure bash per D-04.** Reuses the state-machine pattern from `lint-traps.sh` — 2-space slug headers, 4-space `questions:` opener, 6-space `- qid` list items. Flow-list (`questions: []`) is deliberately unsupported → empty-tracker fixtures fall through the 2nd check as "no refs under this slug".
4. **Environment-override test mode.** `CKA_SIM_LINT_PACKS_DIR` mirrors `lint-packs.sh`; unit cases point it at the fixture tree.

## Deviations from Plan

None — plan 04-03 executed exactly as written. Two minor observations, neither requiring code changes:

- **Plan's secondary acceptance regex is slightly off.** The plan uses `grep -c '^  [a-z][a-z-]*:$'` to assert Workloads has 9 tracker slugs, but that pattern rejects digits so `hpa-autoscaling-v2` isn't counted — it yields 8, not 9. The primary `grep -c 'label:'` check yields 9 as intended, and the content is correct (9 tracker entries match 9 Tracker checkboxes from README §Study Progress Tracker Domain 3). Not a code bug; purely a plan acceptance-regex nit. No fix applied.
- **Plan's automated-verify `python3` is `python` on this Windows host.** Used `python` (PEP 394 Windows convention); semantics identical. No deviation from intent.

## Future Work

- **Plan 04-16** integrates `lint-coverage.sh` into `cka-sim/scripts/validate-local.sh` and `.github/workflows/validate.yml` after Wave 3 (Plans 04-04 through 04-15) has populated both manifests with the 14 question-ids listed in the two coverage.yaml files. Until then, invoking `lint-coverage.sh` against the live packs will exit 1 — this is intentional and documented above.
- **coverage.yaml schema is stable for Phases 5 and 6.** The same `domain:` + `tracker:` two-level shape works for services-networking, cluster-architecture, and troubleshooting packs. Future phases can drop in a new `cka-sim/packs/<pack>/coverage.yaml` with zero lint changes.
- **Orphan cleanup pass in Plan 04-16.** Any question-ids declared in manifest but missing from coverage.yaml will surface as warnings at CI-wiring time; Plan 16 resolves them alongside validate-local.sh integration.

## Issues Encountered

None.

## Next Phase Readiness

- Wave 3 plans (04-04..04-15) can reference Tracker slugs in their SUMMARYs as "closes coverage for `<slug>`" — the slug namespace is now frozen.
- Plan 04-16 has zero blockers: schema, lint behaviour, and fixture contract are all stable.

## Self-Check: PASSED

Files exist:
- `cka-sim/packs/storage/coverage.yaml` — FOUND
- `cka-sim/packs/workloads-scheduling/coverage.yaml` — FOUND
- `cka-sim/scripts/lint-coverage.sh` — FOUND (executable)
- `cka-sim/tests/cases/lint_coverage_schema.sh` — FOUND (executable)
- `cka-sim/tests/cases/lint_coverage_completeness.sh` — FOUND (executable)
- `cka-sim/tests/fixtures/lint-coverage/good/{manifest,coverage}.yaml` — FOUND
- `cka-sim/tests/fixtures/lint-coverage/missing-question/{manifest,coverage}.yaml` — FOUND
- `cka-sim/tests/fixtures/lint-coverage/empty-tracker/{manifest,coverage}.yaml` — FOUND
- `cka-sim/tests/fixtures/lint-coverage/orphan/{manifest,coverage}.yaml` — FOUND

Commits present in `git log --oneline`:
- `93bed96` feat(04-03): add coverage.yaml for storage + workloads-scheduling packs — FOUND
- `b5f505a` feat(04-03): add lint-coverage.sh + 2 unit cases + 4 fixture packs — FOUND

Test suite: `bash cka-sim/scripts/test.sh` exits 0, all 25 cases pass (includes both new `lint_coverage_*` cases).

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
