---
phase: 03-runtime-contract-drill-mode
plan: 05
status: complete
completed: 2026-05-10
subsystem: cka-sim/packs/workloads-scheduling
tags: [workloads-scheduling, deployment, service-account, resources.requests, reference-pack]
requires:
  - cka-sim/lib/grade.sh (assert_resource_exists, assert_field_eq)
  - cka-sim/lib/traps.sh (detect_default_sa_used)
  - cka-sim/traps/catalog.yaml (default-sa-used, deployment-missing-requests, hostpath-pv-without-nodeaffinity)
  - cka-sim/scripts/lint-packs.sh (passes A-E)
provides:
  - workloads-scheduling reference question (1/1 for Phase 3; full pack deferred to Phase 4 PACK-02)
  - canonical wave-3 pattern for Workloads & Scheduling domain graders
affects:
  - cka-sim/scripts/test.sh (step 2 pack-lint now exercises 2 packs: storage + workloads-scheduling)
tech-stack:
  patterns: [idempotent-ns-apply-with-active-wait, kubectl-wait-before-detector, strategic-patch-ref-solution]
key-files:
  created:
    - cka-sim/packs/workloads-scheduling/manifest.yaml
    - cka-sim/packs/workloads-scheduling/README.md
    - cka-sim/packs/workloads-scheduling/01-deployment-requests/metadata.yaml
    - cka-sim/packs/workloads-scheduling/01-deployment-requests/question.md
    - cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh
    - cka-sim/packs/workloads-scheduling/01-deployment-requests/grade.sh
    - cka-sim/packs/workloads-scheduling/01-deployment-requests/reset.sh
    - cka-sim/packs/workloads-scheduling/01-deployment-requests/ref-solution.sh
  modified: []
decisions:
  - "Primary trap is default-sa-used (CONTEXT D-10 row); deployment-missing-requests paired as the other enforced correctness miss; hostpath-pv-without-nodeaffinity listed as filler to satisfy >=3 trap threshold (only the first two are actively detected — third is catalog-registered but unexercised by this question's grade.sh, acknowledged in plan)."
  - "grade.sh wraps detect_default_sa_used in a 60s kubectl wait --for=condition=Available — addresses RESEARCH Assumption A4 (pod must be scheduled before serviceAccountName is readable)."
  - "setup.sh uses a pure kubectl apply heredoc (no kubectl create) for idempotency; lint pass D-09 forbids kubectl delete ns here — runner owns cleanup."
  - "ref-solution.sh uses kubectl patch --type=strategic (not edit) so it is non-interactive and replayable inside CI/human-verify loops."
  - "Deployment image pinned to nginx:1.27 to protect verified_against: '1.35' determinism — question.md constrains the candidate to keep this version."
metrics:
  duration_minutes: 12
  completed_date: 2026-05-10
  tasks_completed: 2
  files_created: 8
  commits: 2
---

# Phase 3 Plan 5: Workloads-Scheduling Reference Pack Summary

One-liner: Ship the first workloads-scheduling question (`01-deployment-requests`) — a Deployment seeded with default SA + no resources.requests, graded by 4 assertions plus the `default-sa-used` detector; second reference pack after `storage/01-pvc-binding` to prove the wave-3 pattern generalises.

## What shipped

Pack scaffold (2 files):
- `cka-sim/packs/workloads-scheduling/manifest.yaml` — pack id `workloads-scheduling`, weight 15, 1 question.
- `cka-sim/packs/workloads-scheduling/README.md` — domain overview, "Phase 3 reference question only; full pack in Phase 4 (PACK-02)".

Question `01-deployment-requests` (6 files, D-12(d/e) compliant):
- `metadata.yaml` — id `workloads-deployment-requests`, domain `workloads-scheduling`, `estimatedMinutes: 7`, `verified_against: "1.35"`, 3 traps (all registered), 2 references.
- `question.md` — candidate prompt: create `load-app-sa`, set `serviceAccountName`, add `resources.requests.cpu: 50m` + `memory: 64Mi`, keep image `nginx:1.27`.
- `setup.sh` — idempotent `kubectl apply` of ns + Active wait (10x5s poll) + Deployment `load-app` with NO `serviceAccountName` and NO `resources.requests` (the seeded trap).
- `grade.sh` — sources `lib/grade.sh` + `lib/traps.sh`; 60s `kubectl wait Available` → 4 assertions (deployment exists, SA == `load-app-sa`, cpu == `50m`, memory == `64Mi`) → `detect_default_sa_used` → `emit_result`.
- `reset.sh` — async `kubectl delete namespace --ignore-not-found --wait=false`; no cluster-scoped resources to clean.
- `ref-solution.sh` — `kubectl apply` SA, `kubectl patch --type=strategic` for SA + resources.requests, `kubectl rollout status` 60s.

## Verification

- `bash cka-sim/scripts/test.sh` — exit 0 (step 1 catalog lint green, step 2 pack lint green across BOTH packs, step 3 all 23 unit cases pass).
- Pack-lint pass accounting: pass A (grade idioms), pass B (mutating verbs — 0 hits in grade.sh), pass C (no `kubectl delete ns` in setup), pass D (6 files + executable bits), pass E (metadata schema + all 3 trap-ids registered in catalog).
- `bash -n` clean on all 4 scripts.

## Trap mapping

| id | declared in metadata | actively detected in grade.sh | rationale |
|---|---|---|---|
| `default-sa-used` | yes | yes (`detect_default_sa_used`) | primary trap for this D-10 question |
| `deployment-missing-requests` | yes | yes, via `assert_field_eq` on `resources.requests.{cpu,memory}` | the correctness miss the candidate must fix |
| `hostpath-pv-without-nodeaffinity` | yes | no | filler to meet the ≥3 threshold from pack-lint pass E; not relevant to this question's setup (no PV involved) — catalog-registered so lint accepts it |

## Human-verification procedure (GRADE-06 round-trip)

Per open Q1 of 03-CONTEXT: lint-passing alone does not prove the runtime contract — a human-driven round-trip is still required (deferred to runner integration in plan 03-06+, but documented here for traceability).

Procedure against a real kind/minikube cluster:
```
export CKA_SIM_ROOT=$(pwd)/cka-sim
export CKA_SIM_LAB_NS=cka-sim-workloads-scheduling-01

bash cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh
bash cka-sim/packs/workloads-scheduling/01-deployment-requests/grade.sh
  # expect SCORE: 1/4 (only "deployment exists" passes) + Trap 1: default-sa-used

bash cka-sim/packs/workloads-scheduling/01-deployment-requests/ref-solution.sh
bash cka-sim/packs/workloads-scheduling/01-deployment-requests/grade.sh
  # expect SCORE: 4/4 + no Trap lines

bash cka-sim/packs/workloads-scheduling/01-deployment-requests/reset.sh
```

## Commits

- `1a72ec2` feat(03-05): add workloads-scheduling pack scaffold (manifest, README, metadata, question)
- `691e89e` feat(03-05): add setup/grade/reset/ref-solution for workloads deployment-requests

## Deviations from Plan

None — plan 03-05 executed exactly as written. All 8 files land, `test.sh` exits 0, the runtime-contract round-trip is documented (but not executed, per Open Q1 = manual step).

## Notes

- `hostpath-pv-without-nodeaffinity` listed as the third trap is intentional plan guidance — the alternative was adding a dedicated workloads-scheduling trap to the catalog just for this question, which plan 03-05 explicitly avoided ("without requiring catalog extension beyond Wave 1"). Future workloads-scheduling questions in Phase 4 PACK-02 can promote a more topical third trap if one is added to the catalog.
- Storage pack (plan 03-04) lands in parallel wave 2 work; when both waves are merged, `test.sh` exercises pack lint against 2 packs — this SUMMARY assumes the storage pack is also present at merge time.

## Self-Check: PASSED

- All 8 files present under `cka-sim/packs/workloads-scheduling/` (verified via `git ls-files`).
- Commit `1a72ec2` present in `git log --oneline`.
- Commit `691e89e` present in `git log --oneline`.
- `bash cka-sim/scripts/test.sh` exits 0 (verified at end of task 2).
