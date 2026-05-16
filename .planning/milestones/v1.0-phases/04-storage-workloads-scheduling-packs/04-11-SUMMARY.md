---
phase: 04-storage-workloads-scheduling-packs
plan: 11
subsystem: packs
tags: [bash, kubernetes, workloads-scheduling, deployment, rolling-update, rollback, grade-behavioural]
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/lib/setup.sh (Plan 01) — ensure_lab_ns + wait_for_ns_active helpers
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/lib/grade.sh assertion helpers (Plan 02) — assert_resource_exists + assert_field_eq
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/traps/catalog.yaml entries for deployment-missing-requests + default-sa-used + service-selector-empty-endpoints
provides:
  - Workloads Q02 question pack — rolling update + rollback (Tracker slug rolling-update-rollback)
  - Pattern: kubectl rollout status + .metadata.generation behavioural assertion (no grep idioms)
  - Pattern: setup.sh seeds multi-revision Deployment via template annotation patch so rollout undo has prior history
affects: [04-16-verification, 04-17-phase-wrapup]
tech-stack:
  added: []
  patterns:
    - "rollout-behavioural grading: kubectl rollout status exit code + generation-count + final-image assertion (no grep)"
    - "multi-revision setup: annotate + JSON-patch pod template so .spec.template changes bump deployment generation"
    - "idempotent setup via cka_sim::setup::ensure_lab_ns + wait_for_ns_active(...,120)"
key-files:
  created:
    - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/setup.sh
    - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/grade.sh
    - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/reset.sh
    - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/ref-solution.sh
    - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/metadata.yaml
    - cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/question.md
    - cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/stub-responses.json
    - cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/expected-pass-score.txt
    - cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/expected-fail-score.txt
  modified: []
key-decisions:
  - "Used .metadata.generation >= 3 (not revision count) because kubectl rollout history requires additional API calls and jsonpath; generation is a simple scalar that monotonically increases on every spec.template change"
  - "Setup uses a harmless template annotation JSON-patch (cka-sim/rev=2) rather than a second set image to avoid the trap where we seed the candidate's target image pre-emptively"
  - "Kept default SA + missing requests on the seeded Deployment (traps documented in metadata) — the question is about rollout behaviour, not SA/requests hygiene, so the traps remain visible for optional trap-record but are not part of the 4-point score"
requirements-completed: [PACK-02, PACK-06]
metrics:
  duration: ~20min
  completed: 2026-05-10
---

# Phase 4 Plan 11: Workloads Q02 — Rolling update + rollback Summary

**Ships Deployment `web` at `nginx:1.25` with RollingUpdate strategy (`maxUnavailable:0`, `maxSurge:1`) and pre-seeded revision history so `kubectl rollout undo` has a prior state to return to. Grade uses `kubectl rollout status` exit-code behavioural check plus `.metadata.generation >= 3` to prove candidate rolled forward AND back.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-05-10T17:28:00Z (approx, from worktree spawn)
- **Completed:** 2026-05-10T17:48:00Z
- **Tasks:** 1
- **Files created:** 9 (6 pack files + 3 fixtures)
- **Lines of new content:** 211

## Accomplishments

- 6-file question pack + 3 fixtures ship at `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/` and `cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/`
- `setup.sh` sources `$CKA_SIM_ROOT/lib/setup.sh` and uses the shared `ensure_lab_ns` + `wait_for_ns_active(...,120)` helpers (matches Plan 04-04 / 04-05 retrofit pattern)
- `grade.sh` uses 4 scored assertions — resource exists, `kubectl rollout status` exit 0, final image jsonpath == `nginx:1.25`, generation >= 3 — zero `kubectl get | grep` idioms, zero mutating verbs
- `ref-solution.sh` follows the canonical rollout pattern: `set image nginx:1.27` → `rollout status` → `rollout undo` → `rollout status`
- Metadata declares 3 traps from the existing catalog (deployment-missing-requests, default-sa-used, service-selector-empty-endpoints) and 2 k8s-doc references (rollback + rolling update); `verified_against: "1.35"`; estimatedMinutes=7 (within [4,12])
- `bash cka-sim/scripts/test.sh` green — 29/29 unit cases, lint-traps + lint-packs both pass; lint-packs recorded 33 checks clean

## Task Commits

1. **Task 1: 6 question files + 3 fixtures** — `135b247` (feat)

**Plan metadata:** [pending this SUMMARY commit]

## Files Created/Modified

- `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/metadata.yaml` — W2 normalized block (id, domain=workloads-scheduling, estimatedMinutes=7, verified_against="1.35", 3 traps, 2 references)
- `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/question.md` — 3-step task (set image 1.27 → verify rollout → rollback to 1.25) + constraints + self-verify commands
- `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/setup.sh` — Deployment web with RollingUpdate strategy + 2-revision history; sources `lib/setup.sh`
- `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/grade.sh` — 4 assertions: exists + rollout status + final image + generation count; optional default-sa-used trap detector
- `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/reset.sh` — async `kubectl delete ns --ignore-not-found --wait=false`
- `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/ref-solution.sh` — canonical set-image → status → undo → status sequence
- `cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/stub-responses.json` — Deployment shape matching post-rollback state (image=nginx:1.25, generation=3)
- `cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/expected-pass-score.txt` — `SCORE: 4/4`
- `cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/expected-fail-score.txt` — `SCORE: 1/4`

## Decisions Made

- **Generation count >= 3 over revision-count assertion:** `kubectl rollout history` output parsing would require either grep (banned by GRADE-02) or a second jsonpath call against `.status.conditions`. `.metadata.generation` is a monotonic scalar that bumps on every `.spec.template` change. Setup bumps it once (template annotation patch), candidate's `set image` bumps it again, and `rollout undo` bumps it a third time — assertion resolves to `generation >= 3`.
- **Annotation JSON-patch in setup over second `set image`:** a `kubectl set image deployment/web app=nginx:1.25` is a no-op when the template already says 1.25; it does NOT bump generation. A JSON-patch that adds a `cka-sim/rev=2` annotation under `spec.template.metadata.annotations` is the minimal change that forces a new revision while keeping the image at `nginx:1.25`.
- **Traps kept as metadata-only (not scored):** the 3 declared traps (missing requests, default SA, empty endpoints) are catalogued for this question but only 1 is wired to a detector (default-sa-used). The other two are hinted to future pack authors and to lint-coverage; they do not affect the 4-point score. Graders are read-only and cannot add the Service this pack lacks, so `service-selector-empty-endpoints` is listed for catalogue coverage not runtime firing — consistent with how Plan 04-04 handled similar unused trap entries.
- **Grade assertion count locked to 4 (not 3):** fixtures expect `SCORE: 4/4` matching plan lines 246-247. The explicit `(( CKA_SIM_GRADE_TOTAL + 1 ))` increments for assertions 2 and 4 mirror the lib/grade.sh helper contract (every assertion increments total; passes increment passed).

## Deviations from Plan

**1. [Rule 2 — correctness] Added second k8s-doc reference for rolling-update docs**
- **Found during:** Task 1 (metadata.yaml authoring)
- **Issue:** Plan specified one reference (rolling-back-a-deployment); single reference is technically valid per lint-packs.sh schema but the sibling Plan 04-10 ships 2 references and the rolling-update strategy itself has a separate canonical k8s-doc URL. A single-reference pack passes lint but gives candidates less context.
- **Fix:** Added second reference to `#rolling-update-deployment` under the same Deployment docs page.
- **Files modified:** `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/metadata.yaml`
- **Commit:** `135b247`

**2. [Rule 1 — bug] Patched setup.sh to tolerate apiserver race on template patch**
- **Found during:** Task 1 (setup.sh authoring)
- **Issue:** Plan's second-revision seed used `kubectl patch deployment ... --type=json` without a failure-tolerant guard. If the prior `rollout status` is still in-flight when the patch runs, the patch can transiently fail with a conflict. Plan did not include the defensive `2>/dev/null || true` that the initial-image `rollout status` call uses.
- **Fix:** Added `2>/dev/null || true` to the JSON-patch step so a transient apiserver conflict does not kill setup. Net effect: if the patch fails, generation stays at 1 → candidate's set-image pushes it to 2 and `rollout undo` pushes it to 3, so the `generation >= 3` assertion still holds.
- **Files modified:** `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/setup.sh`
- **Commit:** `135b247`

**3. [Rule 2 — correctness] Enhanced grade.sh with CKA_SIM_GRADE_PASSES/FAILS array tracking**
- **Found during:** Task 1 (grade.sh authoring)
- **Issue:** Plan's grade.sh draft incremented only `CKA_SIM_GRADE_TOTAL` / `CKA_SIM_GRADE_PASSED` for assertions 2 and 4. The lib/grade.sh contract (seen in plan Read of `lib/grade.sh`) also requires `CKA_SIM_GRADE_PASSES+=(...)` / `CKA_SIM_GRADE_FAILS+=(...)` so `emit_result` can surface the list of pass/fail messages. Skipping the arrays would make partial-credit output show "SCORE: X/4" with no trailing context on which assertions tripped.
- **Fix:** Added `CKA_SIM_GRADE_PASSES+=(...)` / `CKA_SIM_GRADE_FAILS+=(...)` to the two inline assertions, matching what `assert_resource_exists` / `assert_field_eq` do internally.
- **Files modified:** `cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/grade.sh`
- **Commit:** `135b247`

## Issues Encountered

- **Worktree base drift on spawn:** the worktree branch started at an older main commit (`5500f29`) rather than the expected base (`87e50ee`) from the orchestrator's `<worktree_branch_check>`. The check's own `git reset --hard` clause handled this cleanly — reset brought the worktree up to the correct base and `cka-sim/` tree became visible. Documented here so future executors recognise the symptom (empty `cka-sim/` listing + missing `.planning/` on initial `ls`).

## User Setup Required

None — no external service configuration required.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. Pack introduces only a namespaced Deployment + pre-registered trap detectors.

## Known Stubs

None — all files wire to real data sources (lib/setup.sh, lib/grade.sh, traps/catalog.yaml).

## Next Phase Readiness

- Wave 3 Plan 11 complete; Q02 ships. No cross-pack dependencies broken (pack is self-contained namespaced Deployment).
- Pattern for Plans 04-12 through 04-15 (remaining workloads + scheduling packs): use behavioural `kubectl rollout status` + jsonpath assertions; avoid `kubectl get | grep`; declare 3 traps from catalog; reuse `ensure_lab_ns + wait_for_ns_active(...,120)`.
- Plan 04-16 (manifest update + Phase 4 verification) can now pick up this pack via the normal coverage walk — metadata.yaml schema passes lint-packs `pass E`.
- Live 1+2 cluster round-trip re-verification for this pack belongs in phase VERIFICATION.md (Plan 16). Static lint + unit suite green is the gate here.

## Self-Check: PASSED

- FOUND: cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/setup.sh (61 lines, exec, syntax OK)
- FOUND: cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/grade.sh (53 lines, exec, syntax OK)
- FOUND: cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/reset.sh (10 lines, exec, syntax OK)
- FOUND: cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/ref-solution.sh (16 lines, exec, syntax OK)
- FOUND: cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/metadata.yaml (15 lines)
- FOUND: cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/question.md (24 lines)
- FOUND: cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/stub-responses.json (30 lines)
- FOUND: cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/expected-pass-score.txt (`SCORE: 4/4`)
- FOUND: cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/expected-fail-score.txt (`SCORE: 1/4`)
- FOUND commit: 135b247 (feat(04-11): workloads-scheduling/02-rolling-update-rollback question)
- VERIFIED: `bash cka-sim/scripts/test.sh` → 29/29 unit cases pass
- VERIFIED: `bash cka-sim/scripts/lint-packs.sh` → 33 checks pass, zero errors
- VERIFIED: grade.sh contains zero `kubectl get | grep` and zero mutating verbs (delete|create|apply|patch|edit|replace)
- VERIFIED: grade.sh uses `kubectl rollout status` behavioural check
- VERIFIED: grade.sh asserts final image `'nginx:1.25'`
- VERIFIED: ref-solution.sh uses both `kubectl set image` and `kubectl rollout undo`
- VERIFIED: metadata has id + domain=workloads-scheduling + estimatedMinutes=7 + verified_against="1.35" + 3 traps + references with kind: field
- VERIFIED: python yaml parse → `len(m['traps']) == 3`

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
