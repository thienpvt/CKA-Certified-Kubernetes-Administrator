---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: CKA-PREP-2025-v2 Pack
status: planning
last_updated: "2026-05-29T03:55:59.358Z"
last_activity: 2026-05-29
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# State

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Roadmap approved; ready to start Phase 29
Last activity: 2026-05-29 — Milestone v1.2 requirements and roadmap approved

### v1.2 Roadmap Snapshot (approved)

- Phase 29: Source Inventory + Pack Scaffold + Storage/Manifest Exercises — SRC-04..06, PACK-05..08, VJQ-01, VJQ-02, VJQ-06, VJQ-14 (11 reqs) — Pending
- Phase 30: Workloads + Scheduling Exercise Batch — VJQ-03, VJQ-04, VJQ-05, VJQ-07, VJQ-10 (5 reqs) — Pending
- Phase 31: Networking + Add-On Exercise Batch — VJQ-08, VJQ-11, VJQ-12, VJQ-13, VJQ-16, VJQ-17 (6 reqs) — Pending
- Phase 32: Runtime + Control-Plane Safety Exercises — VJQ-09, VJQ-15 (2 reqs) — Pending
- Phase 33: v1.2 Verification + Live UAT Batch — VER-06..10 (5 reqs) — Pending

Dependency chain: 29 -> 30/31/32 -> 33.

Coverage: 29/29 v1.2 requirements mapped (no orphans, no duplicates).

### v1.1 Roadmap Snapshot (complete; audit passed)

- Phase 25: Source Inventory + Pack Scaffold + Command Exercises — SRC-01..03, PACK-01..04, CMD-01..10 (17 reqs) — Complete
- Phase 26: Core Object Exercise Batch — OBJ-01..10 (10 reqs) — Complete
- Phase 27: Operational Exercise Batch — OPS-01..10 (10 reqs) — Complete
- Phase 28: v1.1 Verification + Live UAT Batch — VER-01..05 (5 reqs) — Complete

Dependency chain: 25 → 26 → 27 → 28.

Coverage: 42/42 v1.1 requirements mapped and satisfied (no orphans, no duplicates).

### v1.1 Audit Result (2026-05-28)

Milestone audit `.planning/v1.1-MILESTONE-AUDIT.md` status is `passed`: all 42 requirements, live validation gates, and Nyquist validation artifacts pass.

Next step:

- Run `$gsd-complete-milestone 1.1`, then `$gsd-cleanup`.

### v1.0.3 Roadmap Snapshot (archived — milestone shipped)

- Phase 22: Surgical Tech-Debt Fixes — DRILL-NS-01, AUDIT-W&S06, LINT-01 (3 reqs) — Complete
- Phase 23: GHA Environmental Forensics + Lint Triage — BLG-06, BLG-07 (2 reqs) — Complete
- Phase 24: v1.0.3 Sign-Off + Lab UAT Batch — sign-off phase (no new REQ-IDs; UAT-verifies Phase 22 + Phase 23) — Complete

Dependency chain: 22 ‖ 23 → 24. All phases shipped.

Coverage: 5/5 v1.0.3 requirements satisfied (no orphans, no duplicates).

- DRILL-NS-01 → Phase 22 — satisfied (commit 75ed497, lab UAT ✓)
- AUDIT-W&S06 → Phase 22 — satisfied (commit 7c87e1a, lab UAT ✓)
- LINT-01 → Phase 22 + Phase 24 follow-up — satisfied (commits d1b244e + 15e652d, lab UAT ✓)
- BLG-06 → Phase 23 — satisfied (commit 0a9e08f, GHA validate.yml ✓)
- BLG-07 → Phase 23 — satisfied (commit 3e7cff4, GHA bash-tests ✓)

### v1.0.3 Close-Out (2026-05-21 ship; live UAT closed 2026-05-21)

All 3 phases (22, 23, 24) shipped. 5/5 v1.0.3 requirements satisfied; static gates green; lab UAT batch confirmed on v1.0.1 GCP lab cluster; GHA `validate.yml` (validate-local + bash-tests) exits 0 on the milestone-close push.

- Phase 22: Surgical Tech-Debt Fixes — DRILL-NS-01, LINT-01, AUDIT-W&S06 — commits `79dcdbe..91a258c`
- Phase 23: GHA Environmental Forensics + Lint Triage — BLG-06, BLG-07 — commits `802f27c..607f538`
- Phase 24: v1.0.3 Sign-Off + Lab UAT Batch — uat-v103.sh + milestone audit doc — commits `e319d5c..15e652d`

**Lab UAT (2026-05-21):** `cka-sim/scripts/uat-v103.sh` ran on v1.0.1 lab cluster; result `3 passed / 0 failed / 2 skipped (of 5)` (BLG-06/BLG-07 are GHA-deferred sub-checks by design). LINT-01 required a follow-up fix (commit `15e652d`) to reverse mutation direction post-Phase 10 BUG-H01 reshape; second UAT run green. Evidence: `cka-sim/current-tests/step6-results.txt`.

**GHA confirmation (2026-05-21):** `validate.yml` `validate-local` job (no `continue-on-error`) and `bash-tests` job both exit 0 on the v1.0.3 milestone-close push.

Per-REQ commit citations:

- DRILL-NS-01 → `75ed497` (Plan 22-01) — lab UAT ✓
- LINT-01 → `d1b244e` (Plan 22-02) + `15e652d` (Phase 24 follow-up) — lab UAT ✓
- AUDIT-W&S06 → `7c87e1a` (Plan 22-03) — lab UAT ✓
- BLG-06 → `0a9e08f` (Plan 23-01) — GHA validate-local ✓
- BLG-07 → `3e7cff4` (Plan 23-02) — GHA bash-tests ✓

Detail in `.planning/milestones/v1.0.3-MILESTONE-AUDIT.md`.

### v1.0.2 Close-Out (2026-05-20 ship; live UAT closed 2026-05-20)

All 6 phases (16-21) plus 4 inserted sub-phases (19.1, 19.2, 20.1, 20.2) shipped with `tech_debt` audit status. 18/18 requirements code-complete; all 4 forensic findings closed with live-cluster UAT evidence. Per-phase commit ranges in `.planning/milestones/v1.0.2-MILESTONE-AUDIT.md` and ledger detail in `.planning/forensics/FORENSIC-v102.md`.

- Phase 16: Question-Intent Baseline Harness — BASELINE-01..04 + DOC-01 — commits `d19f550..c12a0ee`
- Phase 17: v1.0.2 Backlog Cleanup — BLG-01..05 — commits `3ccb35a..e14baf7` (BLG-06 routed to v1.0.3)
- Phase 18: Forensic Re-Audit (Blind) — AUDIT-01..04 — commit `c56749a`
- Phase 19.1/19.2/20.1/20.2: HIGH+MED Remediation — BUG-H07/H08/M11/M12 — commit `0424b64`
- Phase 21: Sign-Off — commit `3574ce1` (milestone shipped tech_debt)

**Live Lab UAT (2026-05-20):** Lab cluster v1.0.1 (1 CP + 2 workers, Calico, enforcing CNI) at HEAD `e2f7546`. Driver `cka-sim/scripts/uat-phase18-21.sh` mirrors v1.0.1's `uat-phase10/11/13.sh` shape.

- Result: **9 passed, 0 failed, 0 skipped (of 9)** — every BUG-* sub-check green
- BUG-H07: H07.1 grep -F shape present, H07.2 setup.sh exits 0 under LC_ALL=C, H07.3 empty=0/N, H07.4 ref=max/max + 0 traps
- BUG-H08: H08.1 empty=0/4, H08.2 ref=4/4 + 0 traps
- BUG-M11: M11.1 `cka-sim audit cluster-architecture/04-pss-enforce` returns PASS (3/3) on real cluster
- BUG-M12: M12.1 report_golden unit case passes, M12.2 expected-report.md is LF-only

**Audit re-run on real cluster (Step 2):** 33/34 PASS, 0 FAIL, 1 error, 0 skipped — `BLG-02 unsupported-on-kind` flag removed from the 3 affected questions; only `workloads-scheduling/06-static-pod` setup.sh fails on the lab cluster (separate from the 4 forensic findings; routed to v1.0.3 scope as AUDIT-W&S06).

UAT artifacts: `cka-sim/current-tests/step{1,2,4,5}-results.txt`. FORENSIC-v102.md Closure Status table updated with `closed-by` + `Live UAT` columns (commits `0424b64` for code, `e2f7546` for UAT).

### v1.0.2-followups (Tech Debt — routed to v1.0.3)

Carried forward from v1.0.2 close-out. All 3 items now scoped as REQs DRILL-NS-01/AUDIT-W&S06/LINT-01/BLG-06/BLG-07 across Phases 22-23:

1. **BLG-06** — Per-finding shellcheck/yamllint triage. `continue-on-error: true` scaffolded in P17 (commit `a77712a`); per-finding fixes deferred per Plan 17-05's documented flow. → Phase 23.
2. **BLG-07** — GHA bash-tests environmental reds. 9 unit-test cases fail on `ubuntu-latest` runners but pass on Docker Ubuntu 22.04 + 24.04 + Windows MSYS. Surfaced after Phase 17 fixed `tests/run.sh` exec bit. Symptom: `expected 1 got 0` on `cka_sim::baseline::is_candidate_modified` unchanged-baseline branch. Investigate runner-specific environmental delta (jq version, locale, `set -u` interaction). → Phase 23.
3. **Audit error: `workloads-scheduling/06-static-pod`** — setup.sh failed on the lab cluster during Step 2 audit re-run (ns=cka-sim-audit-...). Not a kind-skip — real-cluster setup-drift. → Phase 22 as AUDIT-W&S06.

Two additional v1.0.3 requirements not in the v1.0.2-followups list (surfaced separately):

4. **DRILL-NS-01** — drill-mode `${CKA_SIM_LAB_NS}` literal display bug. Mirrors exam-mode quick task `260517-hvo` (commit on `cka-sim/lib/cmd/exam.sh`). → Phase 22.
5. **LINT-01** — symptom-diff regression test silently passes when comparison fails; `Bad file descriptor` on `cka-sim/lib/symptom-diff.sh:94` masks lint detection; Phase 15's quality gate silently broken. → Phase 22.

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

- 2026-05-21 — Milestone v1.0.3 roadmap drafted: 3 phases (22-24), 5/5 v1.0.3 requirements mapped. Phase 22 (Surgical Tech-Debt Fixes) and Phase 23 (GHA Environmental Forensics + Lint Triage) are parallel-eligible by design — surgical fixes touch disjoint code paths (drill renderer, one question's setup.sh, `lib/symptom-diff.sh`); investigation phase touches GHA workflow + bash-test infrastructure. Phase 24 closes the milestone via lab-cluster UAT batch + `v1.0.3-MILESTONE-AUDIT.md`, mirroring v1.0.1's Phase 15 / v1.0.2's Phase 21 sign-off shape. No placeholder phases like v1.0.2's 19/20 — there's no forensic ledger gating sub-phase shape this milestone.
- 2026-05-19 — Milestone v1.0.2 roadmap drafted: 6 phases (16-21), 18/18 requirements mapped. Phases 16+17 parallel-eligible (greenfield audit harness vs. pre-traced backlog cleanup). Phases 19+20 are placeholders by design — sub-phases generated from FORENSIC-v102.md ledger via `/gsd-phase --insert` after Phase 18 ships, mirroring how v1.0.1 P10-P14 derived from the forensic report. Phase 21 closes the milestone with intent re-audit + live UAT batch.
- 2026-05-17 — Milestone v1.0.1 opened. Forensic audit (`forensics/report-20260517-091657-full-audit.md`) surfaced 6 HIGH + 9 MED question bugs + 1 library typo. Roadmap defined 6 phases (10-15) covering 18 requirements with 100% coverage.
- Phase 07.1 inserted after Phase 7: Grading honesty rebuild — empty submissions must score 0/100 (Phase 7 UAT Test 12) (URGENT)
- 2026-05-15 — Phase 07 COMPLETE. All 7 plans landed (07-01..07-07). UAT Test 2 (signal handling) closed via 07-07 + 15-commit follow-up chain (re-run #4 ✅). Test 12 acknowledged + deferred to 07.1.

### Decisions

- 2026-05-21 — v1.0.3 phase shape: 3 phases (22-24) reflecting the 5-requirement tech-debt surface. Phase 22 groups all three independent surgical fixes (DRILL-NS-01 + AUDIT-W&S06 + LINT-01) — each is a single-point change in disjoint files, so they batch cleanly into one phase. Phase 23 isolates the two investigation-heavy items (BLG-06 per-finding lint walk, BLG-07 runner-environment forensics) where the work shape is "iterate per finding" or "compare environments," not "apply known fix." Phase 24 is a milestone close-out + lab UAT batch — the same shape that worked for v1.0.1 (P15 verification) and v1.0.2 (P21 sign-off).
- 2026-05-21 — Phase 22 and Phase 23 are parallel-eligible. The two phases touch disjoint subsystems: Phase 22 = drill renderer + one question's setup.sh + `lib/symptom-diff.sh` line-94 swallowed-error path; Phase 23 = GHA workflow YAML + bash-test infrastructure on `ubuntu-latest`. No shared files, no shared decisions.
- 2026-05-21 — No placeholder phases this milestone. Unlike v1.0.2's Phases 19/20 (which were placeholders waiting on FORENSIC-v102.md to drive sub-phase shape), all 5 v1.0.3 requirements are pre-traced from v1.0.2 close-out evidence. Direct phase assignment, no `/gsd-phase --insert` round-trip needed.
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

- Start the next milestone with /gsd-new-milestone

## Quick Tasks Completed

| Date       | Quick ID   | Slug                          | Files                                  |
|------------|------------|-------------------------------|----------------------------------------|
| 2026-05-17 | 260517-hvo | exam-substitute-lab-ns        | `cka-sim/lib/cmd/exam.sh`              |
