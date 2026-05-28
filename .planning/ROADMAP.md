# Roadmap: CKA Certified Kubernetes Administrator

## Milestones

- ✅ **v1.0 CKA Exam Simulator MVP** — Phases 1-8 + 07.1 (shipped 2026-05-17)
- ✅ **v1.0.1 Full Audit Remediation** — Phases 10-15 (shipped 2026-05-18, tech_debt; live UAT closed 2026-05-19)
- ✅ **v1.0.2 Question Correctness Audit + Backlog Cleanup** — Phases 16-21 + 19.1/19.2/20.1/20.2 (shipped 2026-05-20, tech_debt; live UAT closed 2026-05-20; GHA bash-tests env reds + BLG-06 lint triage routed to v1.0.3)
- ✅ **v1.0.3 Tech Debt + Drill UX Fixes** — Phases 22-24 (shipped 2026-05-21; lab UAT + GHA validate.yml green)
- 📋 **v1.1 Dump Cooloo9871 Pack** — Phases 25-28 (planned 2026-05-28; 42 requirements)

## Phases

<details>
<summary>✅ v1.0 CKA Exam Simulator MVP (Phases 1-8 + 07.1) — SHIPPED 2026-05-17</summary>

- [x] Phase 1: Cluster Bootstrap + Runner Skeleton (2/2 plans) — bootstrap, doctor, SSH topology
- [x] Phase 2: Trap Framework + Assertion Library (5/5 plans) — grade.sh, traps.sh, catalog
- [x] Phase 3: Runtime Contract + Drill Mode (9/9 plans) — `cka-sim drill`, 5 reference questions
- [x] Phase 4: Storage + Workloads-Scheduling Packs (18/18 plans) — 14 questions across 2 packs
- [x] Phase 5: Services-Networking + Cluster-Architecture Packs (20/20 plans) — 14 questions across 2 packs
- [x] Phase 6: Troubleshooting Pack (9/9 plans) — 6 troubleshooting questions
- [x] Phase 7: Exam Mode + Blueprint Alpha + Reporting (7/7 plans) — `cka-sim exam`, timer, signals, reports
- [x] Phase 07.1: Grading Honesty Rebuild (INSERTED — URGENT) (13/13 plans) — empty submission = 0/100
- [x] Phase 8: Blueprint Bravo + Banners + Docs + CI (5/5 plans) — second exam, docs, shellcheck CI

Full archive: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0.1 Full Audit Remediation (Phases 10-15) — SHIPPED 2026-05-18 (tech_debt; live UAT closed 2026-05-19)</summary>

Drove every fix from per-bug evidence in `forensics/report-20260517-091657-full-audit.md` (15 question bugs + 1 library typo + 2 systemic CI gates). 18/18 requirements code-complete, 8 satisfied + 10 addressed (uat closed 2026-05-19).

- [x] Phase 10: HIGH Single-Question Edits (4/4 plans) — BUG-H01..H04 — commits `effcc3c..ce52428` + `6bcfaad` (verification)
- [x] Phase 11: HIGH Grader/Question Rework (2/2 plans) — BUG-H05, BUG-H06 — commits `3dbe2d0..c6821b9` + `87d8fc4` (verification)
- [x] Phase 12: Trap-Coverage Lint + Orphan Cleanup (5/5 plans) — LINT-01, BUG-M01..M03 — commits `fc508a7..532a539` + `84e99f7` (verification)
- [x] Phase 13: Grader-Strengthening (3/3 plans) — BUG-M04..M06 — commits `e0fa449..d267419` + `fbcf867` (verification)
- [x] Phase 14: Question Framing + Library Fixes (4/4 plans) — BUG-M07..M09, LIB-01 — commits `d411c05..ef11f08` + `7f165a5` (verification)
- [x] Phase 15: Live-Cluster Symptom-Diff CI (7/7 plans) — CI-01 — commits `bd29f0e..d75f4bd` + `5329d4d` (verification)

Full archive: [milestones/v1.0.1-ROADMAP.md](milestones/v1.0.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0.2 Question Correctness Audit + Backlog Cleanup (Phases 16-21 + 19.1/19.2/20.1/20.2) — SHIPPED 2026-05-20 (tech_debt; live UAT closed 2026-05-20)</summary>

Question correctness audit + backlog cleanup. 6 phases (16-21) plus 4 inserted sub-phases (19.1, 19.2, 20.1, 20.2). All 4 forensic findings (BUG-H07/H08/M11/M12) closed in code (`0424b64`) + verified on lab cluster via `uat-phase18-21.sh` (9/9 PASS, commit `e2f7546`). FORENSIC-v102.md ledger locked with `closed-by` references. Audit re-run on real cluster: 33/34 PASS (1 setup-drift in workloads-scheduling/06-static-pod routed to v1.0.3 as AUDIT-W&S06). BLG-06 per-finding triage and BLG-07 GHA bash-tests env reds routed to v1.0.3.

- [x] Phase 16: Question-Intent Baseline Harness (TBD plans) — BASELINE-01..04 + DOC-01 — commits `d19f550..c12a0ee`
- [x] Phase 17: v1.0.2 Backlog Cleanup (TBD plans) — BLG-01..05 — commits `3ccb35a..e14baf7` (BLG-06 routed to v1.0.3)
- [x] Phase 18: Forensic Re-Audit (Blind) (2/2 plans) — AUDIT-01..04 — commit `c56749a`
- [x] Phase 19: HIGH-Severity Remediation (Placeholder) (2/2 sub-phases)
- [x] Phase 19.1: BUG-H07 Close — locale-safe grep — commit `0424b64`
- [x] Phase 19.2: BUG-H08 Close — audit-policy grader vs fixture — commit `0424b64`
- [x] Phase 20: MED-Severity Remediation (Placeholder) (2/2 sub-phases)
- [x] Phase 20.1: BUG-M11 Close — harness label extraction — commit `0424b64`
- [x] Phase 20.2: BUG-M12 Close — report_golden re-baseline — commit `0424b64`
- [x] Phase 21: Post-Fix Intent Re-Verification + Sign-Off (TBD plans) — commit `3574ce1`

Full archive: [milestones/v1.0.2-MILESTONE-AUDIT.md](milestones/v1.0.2-MILESTONE-AUDIT.md)

</details>

### ✅ v1.0.3 Tech Debt + Drill UX Fixes — SHIPPED 2026-05-21

<details>
<summary>v1.0.3 phases (22-24) — 5/5 requirements satisfied; lab UAT + GHA confirmation green</summary>

5 fix-bug requirements closed across 3 phases. Lab UAT on v1.0.1 GCP cluster reported 3/0/2 (BLG-06/BLG-07 are GHA-deferred sub-checks). GHA `validate.yml` (`validate-local` + `bash-tests` jobs) exits 0 on the milestone-close push.

- [x] Phase 22: Surgical Tech-Debt Fixes (3/3 plans) — DRILL-NS-01, AUDIT-W&S06, LINT-01 — commits `79dcdbe..91a258c`
- [x] Phase 23: GHA Environmental Forensics + Lint Triage (2/2 plans) — BLG-06, BLG-07 — commits `802f27c..607f538`
- [x] Phase 24: v1.0.3 Sign-Off + Lab UAT Batch (2/2 plans) — uat-v103.sh + milestone audit — commits `e319d5c..15e652d`

Full archive: [milestones/v1.0.3-MILESTONE-AUDIT.md](milestones/v1.0.3-MILESTONE-AUDIT.md), [milestones/v1.0.3-ROADMAP.md](milestones/v1.0.3-ROADMAP.md), [milestones/v1.0.3-REQUIREMENTS.md](milestones/v1.0.3-REQUIREMENTS.md)

</details>

### 📋 v1.1 Dump Cooloo9871 Pack — PLANNED

Add a new `dump-cooloo9871` drill pack with 30 original, v1.35-compatible exercises derived from the cooloo9871 CKA source topics. The milestone keeps source usage to topic inventory only and preserves existing simulator contracts: bash-only runtime, idempotent setup/reset, trap-aware grading, grading honesty, and lint/UAT evidence.

- [ ] Phase 25: Source Inventory + Pack Scaffold + Command Exercises — SRC-01..03, PACK-01..04, CMD-01..10
- [ ] Phase 26: Core Object Exercise Batch — OBJ-01..10
- [ ] Phase 27: Operational Exercise Batch — OPS-01..10
- [ ] Phase 28: v1.1 Verification + Live UAT Batch — VER-01..05

## Phase Details

### Phase 25: Source Inventory + Pack Scaffold + Command Exercises

**Goal:** Establish `dump-cooloo9871` pack structure, adaptation ledger, and all lower-risk command/inspection exercises.

**Requirements:** SRC-01, SRC-02, SRC-03, PACK-01, PACK-02, PACK-03, PACK-04, CMD-01, CMD-02, CMD-03, CMD-04, CMD-05, CMD-06, CMD-07, CMD-08, CMD-09, CMD-10

**Success criteria:**
1. `cka-sim/packs/dump-cooloo9871` exists with README, manifest, coverage map, and 30 planned entries.
2. Source inventory maps all 30 approved topics with v1.35 adaptation notes and prior-art metadata references.
3. Q01/Q05/Q07/Q08/Q14/Q15/Q16/Q22/Q23/Q28 command/inspection exercises have complete seven-file runtime directories.
4. Pack discovery and static lint gates pass for scaffold plus command/inspection questions.

### Phase 26: Core Object Exercise Batch

**Goal:** Add the standard Kubernetes object-authoring exercises for stateful workloads, storage, RBAC, scheduling objects, secrets, policy, and service traffic.

**Requirements:** OBJ-01, OBJ-02, OBJ-03, OBJ-04, OBJ-05, OBJ-06, OBJ-07, OBJ-08, OBJ-09, OBJ-10

**Success criteria:**
1. Q03/Q06/Q10/Q11/Q12/Q13/Q19/Q24/Q29/Q30 exercises have complete runtime directories.
2. Empty-submission paths fail scored assertions because required candidate object state is absent or wrong.
3. Reference solutions reach max score in static/unit fixture paths where offline fixture coverage exists.
4. Pack, coverage, trap, and question-symptom lint remain green after the object batch.

### Phase 27: Operational Exercise Batch

**Goal:** Add the high-risk scheduling, node, control-plane, API, and etcd exercises with reversible lab-safe setup/reset behavior.

**Requirements:** OPS-01, OPS-02, OPS-03, OPS-04, OPS-05, OPS-06, OPS-07, OPS-08, OPS-09, OPS-10

**Success criteria:**
1. Q02/Q04/Q09/Q17/Q18/Q20/Q21/Q25/Q26/Q27 exercises have complete runtime directories.
2. Host/control-plane tasks avoid hard-coded node names and use existing topology discovery or safe simulation.
3. Scheduler, kubelet, static-pod, upgrade/join, and etcd tasks document audit limitations when live-only behavior is required.
4. Reset scripts restore lab state for repeated drills without requiring cluster reprovisioning.

### Phase 28: v1.1 Verification + Live UAT Batch

**Goal:** Prove the full pack is honest, discoverable, lint-clean, and usable on the live lab cluster.

**Requirements:** VER-01, VER-02, VER-03, VER-04, VER-05

**Success criteria:**
1. Empty-submission verification records 0 scored points for all `dump-cooloo9871` exercises.
2. Reference-solution verification records max score for all `dump-cooloo9871` exercises.
3. Static gates pass: pack, coverage, trap, trap-coverage, question-symptom, and unit checks.
4. Live drill UAT covers every high-risk host/control-plane exercise and records setup, grade, reference, and reset evidence.
5. v1.1 milestone audit records requirement coverage, verification evidence, known limitations, and next-step recommendation.

Dependency chain: Phase 25 → Phase 26 → Phase 27 → Phase 28.

Coverage: 42/42 v1.1 requirements mapped, no orphans, no duplicates.

## Progress

**Verification model:** Unit (`cka-sim/scripts/test.sh`) + lint (`lint-packs.sh`, `lint-traps.sh`, `lint-coverage.sh`, `lint-trap-coverage.sh`, `lint-question-symptom.sh`) + GHA `validate.yml` (kind+Calico) during phases. Live drill UATs batched at milestone close (same pattern as v1.0.1 / v1.0.2 / v1.0.3). No local kubectl required during phase execution.

| Phase                                              | Milestone | Plans | Status      | Completed   |
| -------------------------------------------------- | --------- | ----- | ----------- | ----------- |
| 1-8 + 07.1                                         | v1.0      | 88/88 | Complete    | 2026-05-17  |
| 10-15                                              | v1.0.1    | 25/25 | Complete    | 2026-05-18  |
| 16-21 + 19.1/19.2/20.1/20.2                        | v1.0.2    | —     | Complete    | 2026-05-20  |
| 22-24                                              | v1.0.3    | 7/7   | Complete    | 2026-05-21  |
| 25-28                                              | v1.1      | 0/0   | Planned     | —           |
