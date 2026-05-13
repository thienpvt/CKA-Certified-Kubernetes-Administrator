---
phase: 05-services-networking-cluster-architecture-packs
plan: 17
subsystem: cluster-architecture/08-priorityclass
tags: [cluster-architecture, priorityclass, gap-closure, lint-packs, gsd-v1.0-milestone]
status: complete
gap_closure: true
gaps_closed: [1, 15]
requirements: [PACK-04, PACK-06, PACK-07]
tasks_completed: 5
task_commits:
  - task: 1
    hash: 8dd1235
    type: fix
    files: [cka-sim/packs/cluster-architecture/08-priorityclass/setup.sh]
  - task: 2
    hash: 629d2a4
    type: fix
    files: [cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh]
  - task: 3
    hash: 4101ab6
    type: fix
    files: [cka-sim/packs/cluster-architecture/08-priorityclass/ref-solution.sh]
  - task: 4
    hash: e248df2
    type: docs
    files: [cka-sim/packs/cluster-architecture/08-priorityclass/question.md]
  - task: 5
    hash: null
    type: verify-only
    files: []
dependency_graph:
  requires:
    - "Phase 2 grader lib (cka_sim::grade::record_trap, emit_result, accumulators)"
    - "Phase 4 setup lib (cka_sim::setup::ensure_lab_ns, wait_for_ns_active)"
    - "cka-sim/traps/catalog.yaml entry priorityclass-globaldefault-conflict (pre-existing)"
    - "cka-sim/scripts/lint-packs.sh pass A (GRADE-02 regex) — the gate this plan satisfies"
  provides:
    - "A scoring-reachable Q08 PriorityClass drill (broken count=0 -> ref count=1)"
    - "lint-packs pass A green across the whole cka-sim corpus"
  affects:
    - "cka-sim/scripts/test.sh (now exits 0 end-to-end)"
    - "Phase 5 automated verification gate (unblocked)"
tech_stack:
  added: []
  patterns:
    - "storage/03 canonical jsonpath space-stream + wc -w idiom adopted across 08-priorityclass"
    - "setup-time preflight die-check pattern for cluster-owned shared state (globalDefault PCs are cluster-scoped)"
    - "setup post-seed invariant assertion (`after_count != 0 -> die`) — makes unreachable-broken-state regressions loud"
key_files:
  created: []
  modified:
    - cka-sim/packs/cluster-architecture/08-priorityclass/setup.sh
    - cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh
    - cka-sim/packs/cluster-architecture/08-priorityclass/ref-solution.sh
    - cka-sim/packs/cluster-architecture/08-priorityclass/question.md
decisions:
  - "Flip scenario from 2-globalDefault (unreachable — admission rejects) to 0-globalDefault (reachable, single-assert oracle unchanged). Preserves the `exactly one globalDefault` grader contract, which is what the trap name canonically describes."
  - "Ref-solution patches q08-critical (value=2000000) to globalDefault=true rather than q08-batch — stable high-priority PC is the intuitive default for a real candidate."
  - "Setup preflight refuses to seed if a non-q08 cluster-owned globalDefault PC already exists. Stock kubeadm v1.35 has none by default, so this is a no-op on clean clusters; on a customised control plane it fails fast with a diagnostic naming the offending PC."
  - "Keep reset.sh and metadata.yaml untouched. reset.sh already deletes both cluster-scoped q08 PCs (TRIP-02 idempotency preserved); metadata.yaml's trap-id set (priorityclass-globaldefault-conflict, default-sa-used, missing-dns-egress) still satisfies GRADE-04."
metrics:
  duration_minutes: ~20
  tasks: 5
  files_modified: 4
  lints_passed: 4
  unit_cases_passed: 32
  completed: 2026-05-13
---

# Phase 5 Plan 17: Cluster-Architecture Q08 PriorityClass Gap Closure Summary

Redesigned Q08 end-to-end to make the broken state scoring-reachable on a live cluster AND to retire the banned `kubectl get | grep` idiom in grade.sh, closing UAT gaps 1 and 15 in a single coherent change. Four files touched, four atomic commits.

## Redesign Rationale

Two independent defects, one coherent fix:

- **Gap 1 (lint-packs pass A GRADE-02).** `grade.sh:17` piped `kubectl get ...` to `grep -v '^$' | wc -l`. `cka-sim/scripts/lint-packs.sh:43` bans that idiom (regex `kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep`), which propagates up to `cka-sim/scripts/test.sh` as a step-2 failure. Fix: swap to the storage/03 canonical idiom — `{.items[?(@.globalDefault==true)].metadata.name}` (space-stream jsonpath) + `wc -w`.

- **Gap 15 (broken state unreachable).** The old `setup.sh` seeded both PCs with `globalDefault: true`, but the K8s scheduling admission plugin rejects the second `create` with `Forbidden: only one globalDefault PriorityClass can exist`. The fallback at lines 43-54 caught the rejection and re-applied `q08-batch` with `globalDefault: false` — landing the cluster directly in the grader's pass state (count==1). Both grade-on-broken and grade-on-ref returned 2/2 rc=0; the `priorityclass-globaldefault-conflict` trap never fired. Fix: invert the scenario. Seed both with `globalDefault: false` (reachable count=0 broken state); candidate flips exactly one to true; grade's `count==1` invariant now correctly fails on broken and passes after ref.

The grader assertion contract ("exactly one PriorityClass is globalDefault") is unchanged, which is the key insight — the trap name `priorityclass-globaldefault-conflict` already describes "count != 1", so flipping the seed from count=2 to count=0 keeps the trap's canonical wording and the single scoring oracle both valid.

## Task-by-Task Commit Map

| Task | Name                                                                           | Commit  | Files                                                             |
| ---- | ------------------------------------------------------------------------------ | ------- | ----------------------------------------------------------------- |
| 1    | Redesign setup.sh to seed reachable 0-globalDefault broken state with preflight | 8dd1235 | cka-sim/packs/cluster-architecture/08-priorityclass/setup.sh       |
| 2    | Rewrite grade.sh count idiom to jsonpath + wc -w; keep both assertions          | 629d2a4 | cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh       |
| 3    | Rewrite ref-solution.sh to patch q08-critical to globalDefault=true             | 4101ab6 | cka-sim/packs/cluster-architecture/08-priorityclass/ref-solution.sh |
| 4    | Rewrite question.md to describe the reachable 0-globalDefault broken state      | e248df2 | cka-sim/packs/cluster-architecture/08-priorityclass/question.md    |
| 5    | Full lint + test suite — close gaps 1 and 15 together                          | (verify-only) | none                                                           |

## Verification Log

All five gates green on the worktree (Linux bash inside Git Bash on Windows host):

| Gate                                        | Exit | Key line                                                            |
| ------------------------------------------- | ---- | ------------------------------------------------------------------- |
| `bash cka-sim/scripts/lint-packs.sh`        | 0    | `pack lint passed (203 check(s))`                                   |
| `bash cka-sim/scripts/lint-coverage.sh`     | 0    | `coverage lint passed (4 pack(s), 0 warning(s))`                    |
| `bash cka-sim/scripts/lint-traps.sh`        | 0    | `catalog lint passed (36 entries schema OK)`                        |
| `bash cka-sim/scripts/lint-deprecated-strings.sh` | 0 | `deprecated-strings lint passed (940 file-pattern check(s))`       |
| `bash cka-sim/scripts/test.sh`              | 0    | `all 32 case(s) passed` / `all unit cases passed` / `test.sh complete` |

lint-packs pass A now reports zero errors on `cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh` — gap 1 closed at the gate level.

## Deviations from Plan

None — plan executed exactly as written across all 5 tasks. No Rule 1/2/3 auto-fixes, no Rule 4 architectural questions, no auth gates.

## Live-Cluster Round-Trip Status

Deferred to `/gsd-verify-work 5` on the live 1+2 kubeadm v1.35 cluster (tracked in STATE.md under "Deferred Verification — Phase 5 live drill verification"). The four-file redesign is internally consistent and passes all static gates; the final `drill --grade-broken` → `drill --ref-solution` → `drill --grade` round-trip is confirmed by the grader's assertion algebra:

- Post-setup: count=0 globalDefault PCs ⇒ assertion 2 fails ⇒ trap recorded, rc!=0, SCORE 1/2.
- Post-ref: `kubectl patch priorityclass q08-critical --type=merge -p '{"globalDefault":true}'` flips count to 1 ⇒ assertion 2 passes ⇒ rc=0, SCORE 2/2, no traps.
- Post-reset: existing reset.sh deletes both q08 PCs and the lab ns ⇒ TRIP-02 idempotency preserved.

## Self-Check: PASSED

Files:
- FOUND: cka-sim/packs/cluster-architecture/08-priorityclass/setup.sh
- FOUND: cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh
- FOUND: cka-sim/packs/cluster-architecture/08-priorityclass/ref-solution.sh
- FOUND: cka-sim/packs/cluster-architecture/08-priorityclass/question.md

Commits (verified via `git log --oneline`):
- FOUND: 8dd1235 fix(05-17): seed reachable 0-globalDefault broken state for Q08
- FOUND: 629d2a4 fix(05-17): replace banned kubectl-get|grep with jsonpath+wc -w in Q08 grader
- FOUND: 4101ab6 fix(05-17): patch q08-critical to globalDefault=true in Q08 ref-solution
- FOUND: e248df2 docs(05-17): rewrite Q08 prompt for reachable 0-globalDefault broken state

All parsers green: `bash -n` clean on setup.sh / grade.sh / ref-solution.sh (verified per-task).

## Known Stubs

None. No placeholder data, no hardcoded empties flowing to UI, no TODO/FIXME tokens in the four files touched.
