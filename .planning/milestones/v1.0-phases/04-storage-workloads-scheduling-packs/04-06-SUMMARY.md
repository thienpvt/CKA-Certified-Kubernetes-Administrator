---
phase: 04-storage-workloads-scheduling-packs
plan: 06
subsystem: infra
tags: [bash, kubectl, cka-sim, storage, storageclass, dynamic-provisioning, rancher-local-path, pack-question]
# Dependency graph
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: "lib/setup.sh helpers (ensure_lab_ns, wait_for_ns_active) — Plan 01"
  - phase: 04-storage-workloads-scheduling-packs
    provides: "traps/catalog.yaml entries pvc-accessmode-rwx-on-rwo-sc + reclaim-policy-delete-data-loss — Plan 02"
  - phase: 04-storage-workloads-scheduling-packs
    provides: "retrofitted setup.sh sourcing contract — Plan 04 (storage/01-pvc-binding)"
provides:
  - "storage/02-storageclass-dynamic six-file pack question (metadata, question, setup, grade, reset, ref-solution)"
  - "PACK-01 coverage for Tracker slug understand-storageclass-dynamic (question 1 of 2; question 2 lands in Plan 09 05-wait-for-first-consumer)"
  - "GRADE-06 round-trip fixture shape codified under cka-sim/tests/fixtures/storage-02-storageclass-dynamic/ for Plan 16 integration"
affects: [04-07, 04-08, 04-09, 04-10, 04-11, 04-12, 04-13, 04-14, 04-15, 04-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Behavioural grader wait-then-assert: `kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/<name> ... || true` preceding assert_pvc_bound — absorbs provisioner latency without blocking the assertion chain"
    - "WaitForFirstConsumer ref-solution shape: StorageClass + dummy consumer pod to trigger binding, kubectl wait to confirm — applicable to every WFFC-based question"

key-files:
  created:
    - "cka-sim/packs/storage/02-storageclass-dynamic/metadata.yaml — id=storage-storageclass-dynamic, 3 traps (pvc-wrong-storageclass, pvc-accessmode-rwx-on-rwo-sc, hostpath-pv-without-nodeaffinity), 2 k8s-doc references, estimatedMinutes=7"
    - "cka-sim/packs/storage/02-storageclass-dynamic/question.md — PSI-style prose; does not spoiler provisioner choice"
    - "cka-sim/packs/storage/02-storageclass-dynamic/setup.sh — sources lib/setup.sh; seeds ns + PVC app-cache with storageClassName=fast-ssd"
    - "cka-sim/packs/storage/02-storageclass-dynamic/grade.sh — 3 behavioural assertions + pvc-wrong-storageclass detector"
    - "cka-sim/packs/storage/02-storageclass-dynamic/reset.sh — async ns delete + SC fast-ssd cleanup"
    - "cka-sim/packs/storage/02-storageclass-dynamic/ref-solution.sh — rancher.io/local-path StorageClass + consumer pod"
    - "cka-sim/tests/fixtures/storage-02-storageclass-dynamic/{stub-responses.json, expected-fail-score.txt, expected-pass-score.txt} — round-trip fixture triplet"
  modified: []

key-decisions:
  - "Provisioner choice: rancher.io/local-path (already likely present from exercise 12 per RESEARCH §2.1 Q02 external deps); grader is provisioner-agnostic — only checks PVC reaches Bound"
  - "StorageClass volumeBindingMode=WaitForFirstConsumer in ref-solution: matches upstream local-path default, forces a consumer pod to exercise the binder — more representative of real candidate experience than Immediate"
  - "Trap pvc-wrong-storageclass fires only when BOTH PVC is Pending AND SC fast-ssd is absent (per the seeded condition); if candidate creates a different SC, the field_eq assertion on .spec.storageClassName catches that cleanly without a second trap branch"
  - "question.md deliberately says 'dynamic volume binding' and 'backing plugin' rather than the word 'provisioner' — avoids spoilering the YAML field name the candidate must type"
  - "Separate exec-bit fix commit (chore 9aad1e6) instead of --amend: Windows filesystem dropped POSIX +x on initial commit; `git update-index --chmod=+x` forces 100755 in tree so pack-lint pass D passes on Linux CI"

patterns-established:
  - "StorageClass-grade assertion triad: assert_resource_exists storageclass <name> + assert_pvc_bound + assert_field_eq on .spec.storageClassName — confirms (a) SC exists, (b) PVC bound, (c) candidate didn't rewrite the PVC to bypass the challenge"
  - "Two-condition trap detector idiom: `[[ \"$phase\" == \"Pending\" && -z \"$sc_exists\" ]] && record_trap <id>` — cheap re-check after the wait-assert pair; no extra kubectl calls on the happy path"
  - "Round-trip fixture triplet convention: stub-responses.json (seed state) + expected-fail-score.txt (pre-candidate) + expected-pass-score.txt (post-ref-solution) — Plan 16 harness will consume these across every new Phase 4 question"

requirements-completed: [PACK-01, PACK-06]

# Metrics
duration: ~15min
completed: 2026-05-10
---

# Phase 4 Plan 06: storage/02-storageclass-dynamic Summary

**Shipped the six-file StorageClass + dynamic provisioning pack question (PVC `app-cache` + missing StorageClass `fast-ssd` scenario), three-assertion behavioural grader, rancher.io/local-path ref-solution, and round-trip fixture triplet — test.sh + lint-packs.sh green at 18 pack-lint checks + 29/29 unit cases.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-10T17:20Z
- **Completed:** 2026-05-10T17:35Z
- **Tasks:** 2 (+1 exec-bit fix commit)
- **Files created:** 9 (6 pack + 3 fixture)

## Accomplishments
- PACK-01 coverage added for Tracker slug `understand-storageclass-dynamic` (question 1 of 2; question 2 is Plan 09 05-wait-for-first-consumer)
- Three behavioural assertions in grade.sh — no `kubectl get | grep`, no mutating verbs — matching GRADE-02 lint pass A and pass B
- Three registered traps in metadata.yaml: `pvc-wrong-storageclass` (seeded primary), `pvc-accessmode-rwx-on-rwo-sc` (forward-link from Plan 02), `hostpath-pv-without-nodeaffinity` (reuse from Plan 01)
- `pvc-wrong-storageclass` runtime detector embedded inline in grade.sh (no extra lib/traps.sh entry needed — the condition is namespace-ns-local and trivial to re-check)
- WaitForFirstConsumer ref-solution pattern codified: StorageClass + consumer pod + `kubectl wait --for=jsonpath` confirmation — pattern reusable by Plan 09 05-wait-for-first-consumer
- GRADE-06 round-trip fixture triplet staged under `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/` for Plan 16 harness integration
- Pack directory passes lint-packs.sh across all 5 passes (A=GRADE-02, B=mutating-verb, C=D-09, D=6-files+exec-bits, E=metadata schema + trap-id registration)

## Task Commits

1. **Task 1: metadata.yaml + question.md** — `8a0be6c` (feat)
2. **Task 2: setup.sh + grade.sh + reset.sh + ref-solution.sh + 3 fixtures** — `f648973` (feat)
3. **Post-Task-2 exec-bit fix:** `9aad1e6` (chore — Windows-dropped POSIX +x bits forced into git index as 100755)

_No separate metadata commit — plan explicitly excludes STATE.md / ROADMAP.md updates per orchestrator instruction._

## Files Created

### Pack question directory (6 files)
- `cka-sim/packs/storage/02-storageclass-dynamic/metadata.yaml` — id, domain=storage, estimatedMinutes=7, verified_against="1.35", 3 trap-ids, 2 k8s-doc references
- `cka-sim/packs/storage/02-storageclass-dynamic/question.md` — PSI-style prose, uses `${CKA_SIM_LAB_NS}` placeholder, does not mention provisioner name
- `cka-sim/packs/storage/02-storageclass-dynamic/setup.sh` (100755) — sources lib/setup.sh, seeds ns + PVC app-cache requesting `storageClassName: fast-ssd`
- `cka-sim/packs/storage/02-storageclass-dynamic/grade.sh` (100755) — `kubectl wait` + assert_resource_exists + assert_pvc_bound + assert_field_eq + inline `pvc-wrong-storageclass` detector
- `cka-sim/packs/storage/02-storageclass-dynamic/reset.sh` (100755) — async ns delete + cluster-scoped SC fast-ssd cleanup
- `cka-sim/packs/storage/02-storageclass-dynamic/ref-solution.sh` (100755) — rancher.io/local-path SC (WaitForFirstConsumer) + consumer pod + kubectl wait

### Round-trip fixture directory (3 files)
- `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/stub-responses.json` — seed PVC state (Pending, storageClassName=fast-ssd)
- `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/expected-fail-score.txt` — `SCORE: 0/3` for pre-candidate grade run
- `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/expected-pass-score.txt` — `SCORE: 3/3` for post-ref-solution grade run

## Decisions Made
- **Provisioner choice:** `rancher.io/local-path` matches RESEARCH §2.1 Q02 external-deps guidance (already present on lab from exercise 12). The grader is provisioner-agnostic — candidates can substitute any in-cluster provisioner and still score 3/3.
- **volumeBindingMode in ref-solution:** `WaitForFirstConsumer` matches upstream local-path's default; this also exercises the consumer-pod binding sequence, which is closer to real exam shape. An Immediate-mode fallback would have been shorter but less representative.
- **Inline trap detector rather than new lib/traps.sh entry:** the condition (`Pending` + no SC) is cheap and namespace-local; it does not benefit from being parameterised in the shared detector library. Keeps lib/traps.sh surface tight.
- **question.md wording avoids the word "provisioner":** per plan acceptance criteria and PACK-06 spoiler rule. Uses "dynamic volume binding" and "backing plugin" instead.
- **Exec-bit recovery via separate commit, not --amend:** Windows native git strips mode bits on `git add`. The policy prefers new commits over --amend; a three-line `chore:` commit documents the fix explicitly and keeps the bisect-friendly "what happened when" narrative intact.

## Deviations from Plan

Minor rewording in three spots, none affecting semantics or acceptance:

1. **[Rule 1 — Bug prevention] question.md wording tightened to fully avoid the provisioner noun.** Plan's literal text ("supports dynamic provisioning") was correct but the word *provisioning* nudges candidates toward the YAML field name `provisioner:`. Swapped to "supports dynamic volume binding" (Task 1). Satisfies the plan's `! grep -qE 'provisioner' question.md` acceptance check cleanly.
2. **[Rule 1 — Bug prevention] grade.sh comment reworded to avoid a backtick pipe.** Plan's literal comment `# Behavioural (GRADE-02): no \`kubectl get | grep\`.` contained the very substring (`kubectl get ... | grep`) flagged by the plan's (non-anchored) verify grep. lint-packs.sh pass A is anchored (`^[^#]*`) so the comment is not actually linted, but the plan's verify step would have false-alarmed. Swapped to `# Behavioural (GRADE-02): kubectl wait against a jsonpath is the canonical form.` (Task 2). Zero behaviour change.
3. **[Rule 2 — Missing critical] Exec-bit fix commit added.** Plan's Task 2 action said `chmod +x all 4 .sh files` — on Windows this is a filesystem no-op for git's purposes. Added `git update-index --chmod=+x` in a follow-on `chore:` commit (9aad1e6) so the 100755 mode lands in the git tree and lint-packs.sh pass D (executable-bit check) remains green on Linux CI + when contributors clone the repo.

---

**Total deviations:** 3 auto-fixed (2 Rule-1 wording tightenings, 1 Rule-2 exec-bit fix)
**Impact on plan:** All deviations preserve the plan's semantics. Acceptance checks pass byte-for-byte.

## Issues Encountered
- **Worktree HEAD was off-base on agent startup.** `git rev-parse --abbrev-ref HEAD` was correct (`worktree-agent-aa9c0884dfab42c1c`) but the branch had been initialised from the repo's `main` tip (README / exercises skeleton), not from the orchestrator's expected base commit `419c9f2`. Applied the `worktree_branch_check` reset to `419c9f20d99e7f4dc61a94bc70243912925f2b2d` as scripted in the prompt; the `.planning/phases/04-*/` tree then materialised correctly. No work lost (no commits predated the reset).

## User Setup Required
None — no external service configuration required.

## Verification

**Automated (from this worktree):**
- `bash cka-sim/scripts/lint-packs.sh` — exit 0, 18 checks passed (includes the new question dir)
- `bash cka-sim/scripts/test.sh` — exit 0, all 29 unit cases passed
- `bash -n setup.sh grade.sh reset.sh ref-solution.sh` — all four syntax-clean
- Git tree modes: `git ls-files --stage` shows 100755 on all 4 .sh files (exec-bit committed)
- `grep -q 'source.*lib/setup.sh' setup.sh` — sourcing contract confirmed
- `! grep -qE 'kubectl[[:space:]]+get[[:space:]].*\\|[[:space:]]*grep' grade.sh` (anchored form) — GRADE-02 clean
- `! grep -qE 'kubectl[[:space:]]+(delete|create|apply|patch|edit|replace)' grade.sh` — MUTATING-VERB clean
- `! grep -qE 'kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)' setup.sh` — D-09 clean

**Deferred (Plan 16 / phase-end):**
- Live 1+2 cluster GRADE-06 round-trip (drill storage 2 → fails with pvc-wrong-storageclass trap → ref-solution → drill storage 2 → 3/3, 0 traps) — per CONTEXT, live-cluster verification is owned by the phase VERIFICATION.md, not per-plan
- Round-trip fixture harness consumption — the 3 fixture files are now staged; Plan 16's `tests/run.sh` extension will iterate them

## Next Phase Readiness
- Plan 07 (Storage Q03 access-modes-reclaim) can reuse the six-file shape verbatim; the `assert_resource_exists + assert_pvc_bound + assert_field_eq` triad is the right template for the RWO/RWX + Retain/Delete scenario
- Plan 09 (Storage Q05 wait-for-first-consumer) can reuse ref-solution.sh's WaitForFirstConsumer-plus-consumer-pod pattern verbatim
- Plan 16 round-trip harness has a second fixture triplet example to wire into `tests/run.sh`
- No STATE.md / ROADMAP.md changes per orchestrator instruction

## Self-Check

- File exists: `cka-sim/packs/storage/02-storageclass-dynamic/metadata.yaml` — FOUND
- File exists: `cka-sim/packs/storage/02-storageclass-dynamic/question.md` — FOUND
- File exists: `cka-sim/packs/storage/02-storageclass-dynamic/setup.sh` — FOUND (100755)
- File exists: `cka-sim/packs/storage/02-storageclass-dynamic/grade.sh` — FOUND (100755)
- File exists: `cka-sim/packs/storage/02-storageclass-dynamic/reset.sh` — FOUND (100755)
- File exists: `cka-sim/packs/storage/02-storageclass-dynamic/ref-solution.sh` — FOUND (100755)
- File exists: `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/stub-responses.json` — FOUND
- File exists: `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/expected-fail-score.txt` — FOUND
- File exists: `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/expected-pass-score.txt` — FOUND
- Commit exists: `8a0be6c` (Task 1 — metadata + question) — FOUND on worktree-agent-aa9c0884dfab42c1c
- Commit exists: `f648973` (Task 2 — scripts + fixtures) — FOUND on worktree-agent-aa9c0884dfab42c1c
- Commit exists: `9aad1e6` (exec-bit fix) — FOUND on worktree-agent-aa9c0884dfab42c1c
- test.sh: 29/29 green
- lint-packs.sh: 18 checks green

## Self-Check: PASSED

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
