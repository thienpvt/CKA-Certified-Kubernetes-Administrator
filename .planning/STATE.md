---
gsd_state_version: 1.0
milestone: v1.0.2
milestone_name: Question Correctness Audit + Backlog Cleanup
status: in_progress
last_updated: "2026-05-19T14:03:05.943Z"
last_activity: 2026-05-19
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# State

## Current Position

Phase: 16 — Question-Intent Baseline Harness (next; parallel-eligible with Phase 17)
Plan: —
Status: Roadmap defined; awaiting `/gsd-plan-phase 16` (or `/gsd-plan-phase 17` — independent dependency chains)
Last activity: 2026-05-19 — Roadmap drafted: 6 phases (16-21), 18/18 requirements mapped

### v1.0.2 Roadmap Snapshot

- Phase 16: Question-Intent Baseline Harness — BASELINE-01..04 + DOC-01 (5 reqs)
- Phase 17: v1.0.2 Backlog Cleanup — BLG-01..06 (6 reqs) — parallel-eligible with Phase 16
- Phase 18: Forensic Re-Audit (Blind) — AUDIT-01..04 (4 reqs)
- Phase 19: HIGH-Severity Remediation (Placeholder) — REMEDIATE-01 (1 req; sub-phases inserted post-Phase 18)
- Phase 20: MED-Severity Remediation (Placeholder) — REMEDIATE-02 (1 req; sub-phases inserted post-Phase 18)
- Phase 21: Post-Fix Intent Re-Verification + Sign-Off — REMEDIATE-03 (1 req)

Dependency chain: 16 ‖ 17 → 18 → 19 (+ 19.x sub-phases) → 20 (+ 20.x sub-phases) → 21.

Coverage: 18/18 v1.0.2 requirements mapped (no orphans, no duplicates). Sub-phase BUG-* requirements are intentionally NOT pre-baked — they are generated from `FORENSIC-v102.md` via `/gsd-phase --insert` after Phase 18 ships, mirroring how v1.0.1's P10-P14 plans were derived from `forensics/report-20260517-091657-full-audit.md`.

### v1.0.1 Close-Out (2026-05-18 ship; UAT closed 2026-05-19)

All 6 phases (10-15) shipped with `tech_debt` audit status. 18/18 requirements code-complete (8 satisfied + 10 addressed). Per-phase commit ranges and audit details in `.planning/milestones/v1.0.1-MILESTONE-AUDIT.md` and `.planning/milestones/v1.0.1-ROADMAP.md`.

- Phase 10: HIGH Single-Question Edits — BUG-H01..H04 — commits `effcc3c..ce52428` + `6bcfaad`
- Phase 11: HIGH Grader/Question Rework — BUG-H05, H06 — commits `3dbe2d0..c6821b9` + `87d8fc4`
- Phase 12: Trap-Coverage Lint + Orphan Cleanup — LINT-01, BUG-M01..M03 — commits `fc508a7..532a539` + `84e99f7` (passed)
- Phase 13: Grader-Strengthening — BUG-M04..M06 — commits `e0fa449..d267419` + `fbcf867`
- Phase 14: Question Framing + Library Fixes — BUG-M07..M09, LIB-01 — commits `d411c05..ef11f08` + `7f165a5` (passed)
- Phase 15: Live-Cluster Symptom-Diff CI — CI-01 — commits `bd29f0e..d75f4bd` + `5329d4d`

### v1.0.1-followups (Tech Debt — closed 2026-05-19)

These are validation tasks for already-shipped code. All closed pre-v1.0.2.

1. **9 live-cluster drill UATs** — Phases 10/11/13: ALL GREEN (2026-05-18)
   - Driven by `cka-sim/scripts/uat-phase{10,11,13}.sh` on the v1.0.1 lab cluster (Calico, enforcing CNI).
   - P10: 12/12 sub-checks. P11: 7/7 sub-checks. P13: 7/7 sub-checks (after BUG-M10 fix).
   - UAT artifacts: `.planning/phases/{10,11,13}-*/{10,11,13}-UAT.md` (commit cc8d230).
   - Driver hygiene: all 3 drivers source `lib/baseline.sh` and wire `prep_baseline` between setup and grade (mirrors `lib/cmd/drill.sh:309-318`).
2. **GHA `symptom-diff` job first run** — Phase 15: EXECUTED (2026-05-19, GHA run 26070172071, head_sha af493ce). Workflow ran end-to-end against kind+Calico. Surface: 18 of 34 questions reported failures across 4 distinct patterns. Full classification in `.planning/phases/15-live-cluster-symptom-diff-ci/15-VERIFICATION.md`. Log archived at `ci-logs/symptom-diff.log` on `gsd/v1.0-milestone` branch. All 18 deferred to v1.0.2 (now scoped as Phase 17 BLG-01..04).
3. **4 fixture regens** — ALL GREEN (2026-05-18, commit 71e97e4):
   - `cka-sim/tests/grading-honesty/services-networking__06-netpol-endport.sh` (0/6→0/4 missing-sentinel branch, 6/6→4/4)
   - `cka-sim/tests/grading-honesty/workloads-scheduling__04-hpa-metrics-server.sh` (0/5→0/7, 5/5→7/7)
   - `cka-sim/tests/grading-honesty/storage__01-pvc-binding.sh` (0/1→0/3, 1/1→3/3) — Phase 10 BUG-H01 collateral
   - `cka-sim/tests/grading-honesty/cluster-architecture__04-pss-enforce.sh` (0/1→0/5, 1/1→5/5) — Phase 10 BUG-H03 collateral
   - Unit suite: 6 reds → 2 reds (the remaining 2 are pre-existing, unrelated — now scoped as Phase 17 BLG-05).

### v1.0.1 grading-honesty leak found and closed (2026-05-18, BUG-M10)

Phase 13 live UAT for workloads-scheduling/04-hpa-metrics-server surfaced a 1-point leak: empty submission scored 1/7 instead of 0/7. Assertion 7 (`kubectl top pod`) bumped TOTAL/PASSED unconditionally — on any cluster with metrics-server alive, A7 returned readings against the setup-seeded q04-load Deployment regardless of candidate work. Same class of leak Phase 07.1 closed.

Fix (commit bfa9755): gate A7 on (HPA exists AND `is_candidate_modified`). TOTAL still increments unconditionally (preserves max=7 stable across paths); PASSED only on the gated path. Two-revision history in `13-UAT.md`'s `Closed Issues` section.

### v1.0.1 Roadmap Snapshot (archived)

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
   - **Note:** This ref-solution shortcut became BUG-H05 in v1.0.1 — the forged-label workaround tested neither `kubectl debug node` nor enforced the skill being graded. Phase 11 closed it.

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

- 2026-05-19 — Milestone v1.0.2 roadmap drafted: 6 phases (16-21), 18/18 requirements mapped. Phases 16+17 parallel-eligible (greenfield audit harness vs. pre-traced backlog cleanup). Phases 19+20 are placeholders by design — sub-phases generated from FORENSIC-v102.md ledger via `/gsd-phase --insert` after Phase 18 ships, mirroring how v1.0.1 P10-P14 derived from the forensic report. Phase 21 closes the milestone with intent re-audit + live UAT batch.
- 2026-05-17 — Milestone v1.0.1 opened. Forensic audit (`forensics/report-20260517-091657-full-audit.md`) surfaced 6 HIGH + 9 MED question bugs + 1 library typo. Roadmap defined 6 phases (10-15) covering 18 requirements with 100% coverage.
- Phase 07.1 inserted after Phase 7: Grading honesty rebuild — empty submissions must score 0/100 (Phase 7 UAT Test 12) (URGENT)
- 2026-05-15 — Phase 07 COMPLETE. All 7 plans landed (07-01..07-07). UAT Test 2 (signal handling) closed via 07-07 + 15-commit follow-up chain (re-run #4 ✅). Test 12 acknowledged + deferred to 07.1.

### Decisions

- 2026-05-19 — v1.0.2 phase shape: 6 phases mirroring v1.0.1's count. Backlog cleanup (Phase 17) sequenced parallel to harness build (Phase 16) because the dependency graphs are independent — Phase 17 closes pre-traced GHA findings against existing code, Phase 16 ships greenfield `cka-sim audit` + intent.yaml corpus. Phase 18 (forensic re-audit) requires both: it needs the harness AND a clean lint baseline so audit signal isn't drowned in known-noise patterns.
- 2026-05-19 — Remediation phases are explicitly placeholders. REMEDIATE-01..03 are written as the requirements to satisfy; concrete BUG-* requirements and decimal sub-phases are generated post-Phase 18 from FORENSIC-v102.md. This pattern matches v1.0.1's actual execution shape (P10-P14 plans were derived from the forensic report, not pre-baked at roadmap time).
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

### v1.0.2 Backlog (folded into Phase 17)

Surfaced 2026-05-19 by GHA run 26070172071 against kind+Calico. None block v1.0.1 ship. All 6 items now scoped as REQs BLG-01..06 in Phase 17.

1. **Symptom-diff Pattern A (12 of 18 failures)** — unsubstituted `${CKA_SIM_LAB_NS}` placeholder in expected-symptom.yaml files. Lint harness uses `cka-sim-lint-<pack>-<slug>` namespaces but the YAMLs contain literal `${CKA_SIM_LAB_NS}`. Fix: harness should expand the placeholder before comparison, OR YAMLs should be rewritten to use the lint namespace pattern. Affected: cluster-architecture/{03,04,05,06,07}, services-networking/05, troubleshooting/{04,05,06}, workloads-scheduling/05, plus 2 more. → BLG-01.
2. **Symptom-diff Pattern B (3 of 18)** — `setup.sh` failed against the lint sandbox for cluster-architecture/02-etcd-backup-restore, storage/04-csi-volumesnapshot, workloads-scheduling/06-static-pod. These need either an `unsupported-on-kind` exclusion list or kind-specific setup variants. → BLG-02.
3. **Symptom-diff Pattern C (3 of 18)** — Phase 10 collateral expected-symptom drift: storage/01-pvc-binding (BUG-H01 reshape — symptom moved from PVC-Pending to Pod-not-scheduling) and cluster-architecture/08-priorityclass (BUG-H04 — kubectl jsonpath returns `<missing>` for unset bool, not `'false'`). Same class as the 4 unit-fixture regens completed this session. → BLG-03.
4. **Symptom-diff Pattern D (3 of 18)** — Deployment-Available timeout: troubleshooting/02-netpol-dns-egress, workloads-scheduling/01-deployment-requests, workloads-scheduling/07-native-sidecar all show `deploy/<x>.status.conditions[Available]=False` instead of `True`. Calico-on-kind stabilization is slower than the lab cluster the YAMLs were authored against. Calico BIRD readiness warnings in the diagnostics dump confirm this. Fix: extend lint timeout, add converge-then-check pre-step, or relax Available expectation. → BLG-04.
5. **CI bash-tests job red on the unit suite reds** — pre-existing, surfaced cleanly now that the workflow runs end-to-end. (storage/02-storageclass-dynamic ref 0/1 vs 1/1; workloads-scheduling/05-daemonset ref 3/4 vs 4/4.) → BLG-05.
6. **CI shellcheck job red** — first run of `validate-local` on Linux surfaced lint warnings on the cka-sim corpus. Investigate scope, decide whether to fix or relax the lint config. → BLG-06.

---

## Operator Next Steps

- Begin v1.0.2 phase planning. Phases 16 and 17 are parallel-eligible — pick whichever offers the cleaner first-cut milestone branch:
  - `/gsd-plan-phase 16` — ship `cka-sim audit` + 38+34 intent.yaml files + AUTHORING.md update.
  - `/gsd-plan-phase 17` — close Phase 15 GHA backlog (BLG-01..06).
- After both ship: `/gsd-plan-phase 18` runs the blind audit and produces FORENSIC-v102.md.
- Post-Phase 18: `/gsd-phase --insert` decimal sub-phases under 19 (HIGH) and 20 (MED) from the ledger, each with its own BUG-* requirements.
- Phase 21 closes the milestone with intent re-verification + live drill UAT batch + v1.0.2-MILESTONE-AUDIT.md.

## Quick Tasks Completed

| Date       | Quick ID   | Slug                          | Files                                  |
|------------|------------|-------------------------------|----------------------------------------|
| 2026-05-17 | 260517-hvo | exam-substitute-lab-ns        | `cka-sim/lib/cmd/exam.sh`              |
