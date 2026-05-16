---
phase: 04-storage-workloads-scheduling-packs
plan: 07
subsystem: infra
tags: [bash, kubectl, cka-sim, storage, pv, pvc, access-modes, reclaim-policy, pack, q03]

# Dependency graph
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: "lib/setup.sh seed_pv_hostpath helper (Plan 01)"
  - phase: 04-storage-workloads-scheduling-packs
    provides: "Plan 02 trap-catalog entries: pvc-accessmode-rwx-on-rwo-sc, reclaim-policy-delete-data-loss"
  - phase: 04-storage-workloads-scheduling-packs
    provides: "Plan 04 retrofit pattern for sourcing lib/setup.sh from setup.sh"
provides:
  - "storage/03-access-modes-reclaim six-file question dir (metadata + question + setup + grade + reset + ref-solution)"
  - "Tracker coverage for both `know-access-modes` and `know-reclaim-policies` slugs via a single bundled scenario"
  - "Round-trip fixture dir under cka-sim/tests/fixtures/storage-03-access-modes-reclaim/ (stub-responses + expected-fail + expected-pass)"
  - "Precedent for bundled-scope questions (two Tracker slugs satisfied by one coherent lab scenario when semantically adjacent)"
affects: [04-08, 04-09, 04-10, 04-11, 04-12, 04-13, 04-14, 04-15, 04-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bundled-scope question pattern — two adjacent Tracker slugs covered by one scenario when both correction types (accessModes + reclaimPolicy) naturally co-occur on the same resource"
    - "Trap-recording idiom for post-hoc conditional traps — compute state via jsonpath into a shell string, branch on it, call record_trap; no `kubectl get | grep`"

key-files:
  created:
    - "cka-sim/packs/storage/03-access-modes-reclaim/metadata.yaml — id, domain=storage, estimatedMinutes=9, verified_against=\"1.35\", 3 trap-ids, 2 k8s-doc references"
    - "cka-sim/packs/storage/03-access-modes-reclaim/question.md — 3-task candidate brief, no spoilers"
    - "cka-sim/packs/storage/03-access-modes-reclaim/setup.sh — sources lib/setup.sh; 2x seed_pv_hostpath; 2 PVC heredocs"
    - "cka-sim/packs/storage/03-access-modes-reclaim/grade.sh — 4 behavioural assertions + 2 conditional record_trap calls"
    - "cka-sim/packs/storage/03-access-modes-reclaim/reset.sh — async ns delete + 2 PV cluster-scoped cleanup"
    - "cka-sim/packs/storage/03-access-modes-reclaim/ref-solution.sh — 2x kubectl patch pv (no delete-recreate)"
    - "cka-sim/tests/fixtures/storage-03-access-modes-reclaim/stub-responses.json"
    - "cka-sim/tests/fixtures/storage-03-access-modes-reclaim/expected-fail-score.txt — SCORE: 1/4"
    - "cka-sim/tests/fixtures/storage-03-access-modes-reclaim/expected-pass-score.txt — SCORE: 4/4"
  modified: []

key-decisions:
  - "Record BOTH pv-accessmodes-mismatch and pvc-accessmode-rwx-on-rwo-sc when the RWX PVC stays Pending with no RWX-capable PV present — the state satisfies both trap definitions and the candidate benefits from seeing both framings (the RESEARCH §2.1 Q03 trap list mandates 3 traps and this is how two of them get exercised on the same failure path)"
  - "Record reclaim-policy-delete-data-loss when q03-retain-pv is still on Retain post-candidate-action — inverse framing of the trap (catalog describes the Delete-as-data-loss risk; the candidate's lesson is that reclaim policy is a deliberate choice, and leaving Retain in defiance of the business-rule change is the mistake the trap flags)"
  - "Use `kubectl get pv -o jsonpath='{.items[?(@.spec.accessModes[0]==\"ReadWriteMany\")].metadata.name}' | wc -w` for RWX-count detection instead of `grep -c .` — keeps grade.sh free of the banned `kubectl get | grep` pattern while staying single-line-behavioural"
  - "Keep PV seeding via `cka_sim::setup::seed_pv_hostpath` with `kubernetes.io/hostname` nodeAffinity on both PVs — the trap focus is accessModes + reclaim, not missing nodeAffinity, so pre-pinning both volumes avoids pulling the Q01 trap into Q03's scope"
  - "ref-solution.sh uses `kubectl patch --type=json` (JSON Patch), not strategic-merge — accessModes is a list where replace semantics matter; JSON Patch makes the transformation explicit and matches the existing ref-solution pattern in storage/01-pvc-binding"

patterns-established:
  - "When two Tracker slugs are semantically adjacent (access modes + reclaim policy both live on PV.spec), cover both in one question via two corrections on two different PVs — saves a question slot, tests broader fluency, matches real-world diagnostic workflow"
  - "Conditional trap recording: compute state via kubectl jsonpath + shell string, branch on it with `[[ ]]`, call `cka_sim::grade::record_trap` — works within grade.sh `set -uo pipefail` without triggering pipefail or the lint-packs mutating-verb guard"

requirements-completed: [PACK-01, PACK-06]

# Metrics
duration: ~6min
completed: 2026-05-10
---

# Phase 4 Plan 07: Ship storage/03-access-modes-reclaim Summary

**Bundled access-modes + reclaim-policy Tracker coverage via one scenario: 2 PVs + 2 PVCs where fixing the RWX PVC's Pending state requires patching PV accessModes, and a separate business-rule change requires flipping the Retain PV's reclaim policy to Delete. Six-file question + three fixtures + full lint-packs.sh and test.sh green.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-05-10T17:20Z
- **Completed:** 2026-05-10T17:27Z
- **Tasks:** 1 (9 files created)

## Accomplishments
- Shipped all 6 question files under `cka-sim/packs/storage/03-access-modes-reclaim/`: metadata.yaml, question.md, setup.sh, grade.sh, reset.sh, ref-solution.sh
- Shipped 3 round-trip fixtures under `cka-sim/tests/fixtures/storage-03-access-modes-reclaim/`: stub-responses.json, expected-fail-score.txt (1/4), expected-pass-score.txt (4/4)
- setup.sh delegates to `cka_sim::setup::seed_pv_hostpath` twice — one call per PV, sourced from `lib/setup.sh` (Plan 01 output)
- grade.sh ships 4 behavioural assertions (2x `assert_pvc_bound`, 2x `assert_field_eq`) + 2 conditional `record_trap` branches covering 3 catalog IDs
- ref-solution.sh applies 2 JSON-Patch ops (no delete-recreate) — matches question.md constraints
- metadata.yaml registers 3 trap IDs all present in `traps/catalog.yaml` (pv-accessmodes-mismatch, pvc-accessmode-rwx-on-rwo-sc, reclaim-policy-delete-data-loss)
- Tracker coverage: `know-access-modes` + `know-reclaim-policies` both satisfied by this single question (per RESEARCH §2.1 Q03 + Plan 03 coverage.yaml)

## Task Commits

Atomic commits per task:

1. **Task 1: Create all 6 question files + 3 fixtures** — `c501dab` (feat)
2. **Task 1 follow-up: Set executable bit on 4 scripts (Windows chmod quirk)** — `a3ea0c5` (chore)

_No STATE.md / ROADMAP.md updates per orchestrator instruction._

## Files Created/Modified

**Created (9):**
- `cka-sim/packs/storage/03-access-modes-reclaim/metadata.yaml`
- `cka-sim/packs/storage/03-access-modes-reclaim/question.md`
- `cka-sim/packs/storage/03-access-modes-reclaim/setup.sh`
- `cka-sim/packs/storage/03-access-modes-reclaim/grade.sh`
- `cka-sim/packs/storage/03-access-modes-reclaim/reset.sh`
- `cka-sim/packs/storage/03-access-modes-reclaim/ref-solution.sh`
- `cka-sim/tests/fixtures/storage-03-access-modes-reclaim/stub-responses.json`
- `cka-sim/tests/fixtures/storage-03-access-modes-reclaim/expected-fail-score.txt`
- `cka-sim/tests/fixtures/storage-03-access-modes-reclaim/expected-pass-score.txt`

**Modified:** none.

## Scenario Rationale (bundled-scope)

Two PVs and two PVCs where each PVC targets a different correction path:

| Resource        | Seeded state          | Candidate target state   | Which Tracker slug      |
| --------------- | --------------------- | ------------------------ | ----------------------- |
| `q03-retain-pv` | RWO / **Retain**      | RWO / **Delete**         | know-reclaim-policies   |
| `q03-delete-pv` | **RWO** / Delete      | **RWX** / Delete         | know-access-modes       |
| `q03-rwo-pvc`   | requests RWO (binds)  | Bound — unchanged        | (baseline)              |
| `q03-rwx-pvc`   | requests RWX (Pending) | Bound (after PV patch) | know-access-modes       |

Binding q03-rwx-pvc forces the candidate to reason about PV accessModes; applying the separate business-rule change forces them to reason about reclaim policy semantics. The two fixes live on different PVs, so the question exercises that PV.spec can carry orthogonal policies and the operator must reason about each independently. The catalog traps line up one-to-one with the two failure modes plus one inverse-framing trap for the accidental-Retain case.

## Trap Map

| Trap ID                              | Fires when                                                             | Candidate lesson                                       |
| ------------------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------ |
| `pv-accessmodes-mismatch`            | q03-rwx-pvc still Pending AND no PV in the cluster advertises RWX      | Binder needs PV accessModes to include every PVC-requested mode |
| `pvc-accessmode-rwx-on-rwo-sc`       | (Same state as above — hostPath StorageClass is RWO-only-capable)      | RWX is a plugin-supported capability; hostPath doesn't offer it |
| `reclaim-policy-delete-data-loss`    | q03-retain-pv still on Retain after candidate declares done            | Reclaim policy is a deliberate choice; don't leave the seeded value when spec calls for change |

`pv-accessmodes-mismatch` and `pvc-accessmode-rwx-on-rwo-sc` both fire on the same Pending-RWX-with-no-RWX-PV state — intentional: they frame the same error condition from different vantage points (binder semantics vs StorageClass capability matrix), which mirrors what the candidate will see in real-cluster diagnostics where both framings apply.

## Decisions Made

- **Both `pv-accessmodes-mismatch` and `pvc-accessmode-rwx-on-rwo-sc` fire on the RWX-still-Pending state.** The plan mandated ≥3 traps and both IDs ship registered. Firing both on the same underlying state (a) teaches the candidate both framings, (b) satisfies the trap-count requirement without fabricating a third unrelated failure mode, and (c) matches how seasoned operators diagnose this state (binder POV _and_ SC capability POV converge on the same fix).
- **`reclaim-policy-delete-data-loss` fires on still-Retain state, not on still-Delete.** The catalog describes the forward risk (leaving Delete surprises you with data loss), but the question's business-rule twist is that Retain is _wrong_ here. Firing the trap on the retain-case surfaces the same catalog prose (reclaim policy is a deliberate choice) to the candidate who forgot to change it. No catalog schema change needed — the description stays correct; only the lab's framing inverts.
- **Kept `kubernetes.io/hostname` nodeAffinity on both PVs.** The Q01 trap (`hostpath-pv-without-nodeaffinity`) isn't in Q03's trap list; pre-pinning prevents that trap from firing as noise in Q03's output and keeps the grader focused on accessModes + reclaim.
- **grade.sh RWX-PV count uses `wc -w` on jsonpath output, not `grep -c`.** Keeps lint-packs.sh pass A (`kubectl get ... | grep` ban) clean while still giving a single-line behavioural count.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Windows git did not persist chmod +x into the index on initial commit**
- **Found during:** Task 1 verification
- **Issue:** `git ls-files --stage cka-sim/packs/storage/03-access-modes-reclaim/` showed `100644` on all four scripts after the first commit `c501dab`, while existing packs show `100755`. `lint-packs.sh` pass D asserts executable bits in the index, not on-disk; would trip on Linux/CI.
- **Fix:** `git update-index --chmod=+x` on all four .sh files, then follow-up commit `a3ea0c5` (chore) to land the mode change.
- **Files modified:** `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh` (mode-only)
- **Commit:** `a3ea0c5`

**2. [Rule 2 - Missing critical functionality] Added `pvc-accessmode-rwx-on-rwo-sc` record to the same conditional as `pv-accessmodes-mismatch`**
- **Found during:** Task 1 authoring
- **Issue:** Plan's grade.sh sketch only recorded `pv-accessmodes-mismatch` inside the Pending-RWX branch, but metadata.yaml declares three traps. Without this second `record_trap` call, only 2 of 3 declared traps could ever fire, and the metadata/grade contract would drift.
- **Fix:** Added `cka_sim::grade::record_trap pvc-accessmode-rwx-on-rwo-sc` inside the same branch — same trigger state, different framing for the candidate.
- **Files modified:** `cka-sim/packs/storage/03-access-modes-reclaim/grade.sh`
- **Commit:** `c501dab`

Otherwise the plan executed exactly as written. The setup.sh / grade.sh / ref-solution.sh shapes match the plan's action block byte-equivalent modulo the Rule 2 fix above.

## Issues Encountered

None that blocked. The initial grade.sh draft used `| grep -c .` on a multi-line jsonpath; caught before commit by re-reading lint-packs.sh pass A; swapped to `wc -w` on a single-line jsonpath.

## Verification

**Plan acceptance criteria:**
- 6 question files present + 4 scripts `chmod +x` (100755 in index after `a3ea0c5`): PASS
- `grep -c 'cka_sim::setup::seed_pv_hostpath' setup.sh` = 2: PASS
- `grep -c 'kubectl patch pv' ref-solution.sh` = 2 (≥2): PASS
- No `kubectl get | grep` in grade.sh (lint-packs pass A clean; the only match is a literal inside a comment, excluded by the `[^#]*` lint pattern): PASS
- No mutating verbs in grade.sh (lint-packs pass B clean): PASS
- Metadata normalized (id, domain=storage, estimatedMinutes=9 in [4,12], verified_against="1.35", 3 traps registered, references[0].kind=k8s-doc): PASS

**Tooling:**
- `bash cka-sim/scripts/lint-packs.sh` → `pack lint passed (18 check(s))` exit 0
- `bash cka-sim/scripts/test.sh` → `all 29 case(s) passed` exit 0
- `for f in cka-sim/packs/storage/03-access-modes-reclaim/*.sh; do bash -n "$f"; done` → all clean

**Round-trip (deferred to live cluster per Plan 16):**
The fixture files record expected results:
- `expected-fail-score.txt`: `SCORE: 1/4` (only q03-rwo-pvc Bound at seed time — the other 3 assertions fail)
- `expected-pass-score.txt`: `SCORE: 4/4` (after ref-solution applies both patches)
Live `setup.sh && grade.sh → fail → ref-solution.sh && grade.sh → pass` round-trip belongs to phase-end VERIFICATION.md (Plan 16 trigger), same as Plans 04–06.

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired components. The setup.sh hostPath directories (`/tmp/q03-retain`, `/tmp/q03-delete`) materialize on PV bind via the existing `DirectoryOrCreate` type setting from `lib/setup.sh::seed_pv_hostpath`.

## Threat Flags

None. The question introduces no new network surface, auth paths, or file-access patterns beyond the hostPath volumes the storage pack already uses (same surface as Plan 04 seeded).

## Next Phase Readiness

- `coverage.yaml` for the storage pack (built in Plan 03) can now check off `know-access-modes` + `know-reclaim-policies` slugs once Plan 16 lint-coverage runs
- Plans 04-08 onwards (workloads-scheduling questions) are unblocked — no shared state with this plan beyond lib/setup.sh which Plan 07 did not modify
- No STATE.md / ROADMAP.md changes per orchestrator instruction

## Self-Check

- File exists: `cka-sim/packs/storage/03-access-modes-reclaim/metadata.yaml` — FOUND
- File exists: `cka-sim/packs/storage/03-access-modes-reclaim/question.md` — FOUND
- File exists: `cka-sim/packs/storage/03-access-modes-reclaim/setup.sh` — FOUND (chmod 100755)
- File exists: `cka-sim/packs/storage/03-access-modes-reclaim/grade.sh` — FOUND (chmod 100755)
- File exists: `cka-sim/packs/storage/03-access-modes-reclaim/reset.sh` — FOUND (chmod 100755)
- File exists: `cka-sim/packs/storage/03-access-modes-reclaim/ref-solution.sh` — FOUND (chmod 100755)
- File exists: `cka-sim/tests/fixtures/storage-03-access-modes-reclaim/stub-responses.json` — FOUND
- File exists: `cka-sim/tests/fixtures/storage-03-access-modes-reclaim/expected-fail-score.txt` — FOUND
- File exists: `cka-sim/tests/fixtures/storage-03-access-modes-reclaim/expected-pass-score.txt` — FOUND
- Commit exists: `c501dab` — FOUND on worktree-agent-a8a01db00c366bdb3 branch
- Commit exists: `a3ea0c5` — FOUND on worktree-agent-a8a01db00c366bdb3 branch
- test.sh: 29/29 case(s) passed
- lint-packs.sh: pack lint passed (18 check(s))

## Self-Check: PASSED

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
