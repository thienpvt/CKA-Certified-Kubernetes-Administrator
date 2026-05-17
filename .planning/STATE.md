---
gsd_state_version: 1.0
milestone: v1.0.1
milestone_name: Full Audit Remediation
status: executing
last_updated: "2026-05-17T09:45:03.551Z"
last_activity: 2026-05-17 -- Phase 10 planning complete
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 4
  completed_plans: 0
  percent: 0
---

# State

## Current Position

Phase: 10 (not started — roadmap drafted, awaiting `/gsd-plan-phase 10`)
Plan: —
Status: Ready to execute
Last activity: 2026-05-17 -- Phase 10 planning complete

### v1.0.1 Roadmap Snapshot

- Phase 10: HIGH Single-Question Edits — BUG-H01, H02, H03, H04
- Phase 11: HIGH Grader/Question Rework — BUG-H05, H06
- Phase 12: Trap-Coverage Lint + Orphan Cleanup — LINT-01, BUG-M01, M02, M03
- Phase 13: Grader-Strengthening — BUG-M04, M05, M06
- Phase 14: Question Framing + Library Fixes — BUG-M07, M08, M09, LIB-01
- Phase 15: Live-Cluster Symptom-Diff CI — CI-01

### Deferred Verification (carried from v1.0)

These are intentionally deferred, not blockers for advancing.

1. **Phase 1 live bootstrap verification** — CLOSED. Bootstrap SSH code exists and is functional. Q06-static-pod requires running `cka-sim bootstrap` once on CP to distribute SSH keys to workers. Nodes accessed via `gcloud ssh` from Cloud Shell for management; inter-node SSH handled by bootstrap.

2. **Phase 2 UAT** — CLOSED (2026-05-13). All 5 tests pass (unit suite, catalog lint, assertion helpers, detectors, RFC 1123).
   - Tracking: `.planning/phases/02-trap-framework-assertion-library/02-UAT.md`

3. **Phase 3 UAT** — CLOSED (2026-05-13). All 5 tests pass (drill command, TRIP-02 idempotency, 5-domain round-trip, AUTHORING.md, GRADE-02 lint).
   - Tracking: `.planning/phases/03-runtime-contract-drill-mode/03-UAT.md`

4. **Phase 4 UAT** — CLOSED (2026-05-13). 7/7 pass. Q05/Q08 grader bugs fixed (commits 0916c98, 9c065c3). Q06-static-pod blocked by SSH env (Phase 1 prerequisite).
   - Tracking: `.planning/phases/04-storage-workloads-scheduling-packs/04-UAT.md`

5. **Phase 5 live drill verification** — CLOSED (2026-05-13). All 14 drills pass on live 1+2 cluster.
   - Tracking: `.planning/phases/05-services-networking-cluster-architecture-packs/05-VERIFICATION.md`
   - Final result: 14/14 PASS (6 S&N + 8 CA). Q06 heredoc bug fixed (815e19a). Gaps 1-4,15 closed by plans 05-17..05-20.

6. **Phase 6 live drill verification** — CLOSED (2026-05-13). All 6 troubleshooting drills + host-safety sweep pass on live 1+2 cluster.
   - Tracking: `.planning/phases/06-troubleshooting-pack/06-HUMAN-UAT.md` and `06-VERIFICATION.md`
   - Final result: 22/22 PASS (6 drills × pre-fix + post-fix + host-safety, plus post-sweep with idempotency). Q04 ref-solution fixed (replaced `kubectl debug node` with explicit privileged debug pod manifest carrying same `kubectl.kubernetes.io/debug-source` label).
   - **Note:** This ref-solution shortcut is now BUG-H05 in v1.0.1 — the forged-label workaround tests neither `kubectl debug node` nor enforces the skill being graded. Phase 11 will fix.

7. **Phase 7 UAT** — CLOSED (2026-05-15). 11/12 pass; Test 12 (scoring honesty) acknowledged and routed to Phase 07.1. Test 2 (signal handling) PASS on re-run #4 after 15 fix commits (be88426 → 62c8c34). Both interactive tests (timer/signals) now verified on live cluster.
   - Tracking: `.planning/phases/07-exam-mode-blueprint-alpha-reporting/07-UAT.md`
   - Bugs fixed (initial wave): missing check_jq (53f0d0b), EOF infinite loop (4f49f9a), stdin leak to setup/grade (314cdc0), subshell losing QDIRS array (d196d46), cmd scripts not executable (9ff8312).
   - Bugs fixed (07-07 gap-closure wave, signal handling): dfd9cc5, 30db50f, 949e08b, plus 15-commit empirical chain be88426 → 62c8c34. See `07-07-SUMMARY.md`.

### Phase 4 automated verification (2026-05-11, all green)

- `bash cka-sim/scripts/test.sh` → 29/29 unit cases pass, exit 0
- `bash cka-sim/scripts/lint-packs.sh` → 51 checks pass, exit 0
- `bash cka-sim/scripts/lint-traps.sh` → 25 catalog entries pass schema, exit 0
- `bash cka-sim/scripts/lint-coverage.sh` → 2 packs at 100% Tracker coverage, 0 warnings, exit 0
- Phase 4 live-drill bugs BUG-1 and BUG-3 are resolved:
  - `cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh` is tracked executable (`100755`).
  - `workloads-scheduling/08-nodeselector-affinity-taints` discovers the first non-control-plane worker dynamically in `setup.sh`, `reset.sh`, `ref-solution.sh`, and `grade.sh`.

## Accumulated Context

### Roadmap Evolution

- 2026-05-17 — Milestone v1.0.1 opened. Forensic audit (`forensics/report-20260517-091657-full-audit.md`) surfaced 6 HIGH + 9 MED question bugs + 1 library typo. Roadmap defines 6 phases (10-15) covering 18 requirements with 100% coverage.
- Phase 07.1 inserted after Phase 7: Grading honesty rebuild — empty submissions must score 0/100 (Phase 7 UAT Test 12) (URGENT)
- 2026-05-15 — Phase 07 COMPLETE. All 7 plans landed (07-01..07-07). UAT Test 2 (signal handling) closed via 07-07 + 15-commit follow-up chain (re-run #4 ✅). Test 12 acknowledged + deferred to 07.1.

### Decisions

- 2026-05-17 — v1.0.1 phase grouping derived from forensic-report bug shape, not arbitrary template: HIGH single-edits (P10), HIGH design rework (P11), lint-then-trim systemic orphans (P12), grader-strengthening (P13), question framing + lib (P14), durable CI net last (P15).
- 2026-05-07 — Rebuild new exam-sim packs from the v1.35 Study Progress Tracker; existing 31 exercises kept as superseded reference-only (not deleted, not retrofitted).
- 2026-05-07 — Target OS: Ubuntu 22.04 (matches PSI real exam env).
- 2026-05-07 — Existing cluster only — no VM provisioning, no `kubeadm init/join` automation.
- 2026-05-07 — Per-question runtime triplet: `setup.sh` / `grade.sh` / `reset.sh`, bash-only, idempotent.
- 2026-05-07 — Grader emits named `Trap N: <description>` diagnostics, not just pass/fail.
- 2026-05-07 — Ship both `cka-sim drill` (single Q) and `cka-sim exam` (timed 2h mock) in v1.0.
- 2026-05-07 — Build five domain packs + two mock-exam packs; mocks compose from packs by reference, never copy.
- 2026-05-07 — SSH topology: candidate works from the control-plane node.
- 2026-05-07 — Bootstrap does NOT inject shell aliases or modify `~/.vimrc`; candidate practices full `kubectl`/`crictl`/`etcdctl` commands for muscle memory. Aliases are opt-in post-bootstrap.
- 2026-05-07 — All K8s resource names (namespaces, cluster-scoped objects, trap IDs, pack IDs) must conform to RFC 1123: lowercase `[a-z0-9-]`, ≤63 chars, alphanumeric start/end. CI-enforced.
- 2026-05-09 — Phase 2 detector contract: explicit per-trap call from grader; positional args + stdout returns trap-id; finalizer formats `Trap N` line from catalog; pure-bash YAML parser (no yq).
- 2026-05-09 — Phase 2 grader contract: failed assertions accumulate (no `die`); each assertion = 1 point; live `✓`/`✗` to stderr, `SCORE:`/`Trap N:` block to stdout; trap dedup by id.
- 2026-05-09 — Phase 2 test harness: PATH-shadowed `kubectl` stub + plain-bash runner; lives at `cka-sim/scripts/test.sh`; new GHA `bash-tests` job; hit/miss/benign fixtures per detector.
- 2026-05-09 — Phase 2 catalog schema: 8 fields per entry (id/name/description/remediation_hint/references/severity/domain/source); `references` is structured `{kind,target,note}`; `lint-traps.sh` enforces schema + paths + seed completeness; `record_trap` validates id at runtime.
- 2026-05-10 — Phase 3 setup-script ns-Active wait extended to 120 s + re-apply if phase=empty; absorbs the `reset.sh --wait=false` race in both drill-driven and bash-driven round-trips. Commit `5c421c1`.
- 2026-05-10 — Phase 3 verified passed on live 1+2 cluster: all 5 reference questions round-trip green (fail_rc!=0 under trap, pass_rc==0 under ref-solution); criterion 1 drill run and criterion 2 TRIP-02 idempotency both confirmed.
- 2026-05-10 — Phase 4 shared helper lib `cka-sim/lib/setup.sh` with 4 functions (ensure_lab_ns, wait_for_ns_active, seed_pv_hostpath, seed_deployment) replaces Phase 3's inline 120 s wait loop; Phase 3 references retrofitted in place.
- 2026-05-10 — Phase 4 trap catalog grew 13 → 25 entries (6 originally locked + 1 W3-revision + 5 on-topic replacements from code review fixes).
- 2026-05-11 — Phase 4 code review landed 3 Critical + 12 Warning fixes in-tree (18 commits `cd73836..3fc45ff`); IN-04 grader-helper refactor and WR-01 full manifest vendoring deferred as non-correctness follow-ups.

### Blockers

- None.

### Pending Todos

- WR-01 deferred: full vendoring of CSI + metrics-server manifests under `cka-sim/vendor/` with recorded SHA256 (non-correctness enhancement)
- IN-04 deferred: `cka_sim::grade::assert_custom` helper + 6-grader retrofit (library API addition, not a correctness bug)

---

## Operator Next Steps

- Start Phase 10 with `/gsd-plan-phase 10` (HIGH single-question edits — BUG-H01..H04)

## Quick Tasks Completed

| Date       | Quick ID   | Slug                          | Files                                  |
|------------|------------|-------------------------------|----------------------------------------|
| 2026-05-17 | 260517-hvo | exam-substitute-lab-ns        | `cka-sim/lib/cmd/exam.sh`              |
