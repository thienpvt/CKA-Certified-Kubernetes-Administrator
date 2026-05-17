# Roadmap: CKA Certified Kubernetes Administrator

## Milestones

- ✅ **v1.0 CKA Exam Simulator MVP** — Phases 1-8 + 07.1 (shipped 2026-05-17)
- ✅ **v1.0.1 Full Audit Remediation** — Phases 10-15 (shipped 2026-05-18, tech_debt — live UAT pending)
- 📋 **v2.0** — Not yet planned (`/gsd-new-milestone` to start)

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
<summary>✅ v1.0.1 Full Audit Remediation (Phases 10-15) — SHIPPED 2026-05-18 (tech_debt — live UAT pending)</summary>

Drove every fix from per-bug evidence in `forensics/report-20260517-091657-full-audit.md` (15 question bugs + 1 library typo + 2 systemic CI gates). 18/18 requirements code-complete, 8 satisfied + 10 addressed (uat_pending).

- [x] Phase 10: HIGH Single-Question Edits (4/4 plans) — BUG-H01..H04 — commits `effcc3c..ce52428` + `6bcfaad` (verification)
- [x] Phase 11: HIGH Grader/Question Rework (2/2 plans) — BUG-H05, BUG-H06 — commits `3dbe2d0..c6821b9` + `87d8fc4` (verification)
- [x] Phase 12: Trap-Coverage Lint + Orphan Cleanup (5/5 plans) — LINT-01, BUG-M01..M03 — commits `fc508a7..532a539` + `84e99f7` (verification)
- [x] Phase 13: Grader-Strengthening (3/3 plans) — BUG-M04..M06 — commits `e0fa449..d267419` + `fbcf867` (verification)
- [x] Phase 14: Question Framing + Library Fixes (4/4 plans) — BUG-M07..M09, LIB-01 — commits `d411c05..ef11f08` + `7f165a5` (verification)
- [x] Phase 15: Live-Cluster Symptom-Diff CI (7/7 plans) — CI-01 — commits `bd29f0e..d75f4bd` + `5329d4d` (verification)

**Tech debt at ship time:** 9 live-cluster drill UATs + 1 GHA first-run + 2 fixture regens deferred as `v1.0.1-followups` (see `milestones/v1.0.1-MILESTONE-AUDIT.md`).

Full archive: [milestones/v1.0.1-ROADMAP.md](milestones/v1.0.1-ROADMAP.md)

</details>

### 📋 v2.0 (Not yet planned)

Use `/gsd-new-milestone` to scope and plan the next milestone.

## Progress

| Phase                                              | Milestone | Plans | Status   | Completed   |
| -------------------------------------------------- | --------- | ----- | -------- | ----------- |
| 1. Cluster Bootstrap + Runner Skeleton             | v1.0      | 2/2   | Complete | 2026-05     |
| 2. Trap Framework + Assertion Library              | v1.0      | 5/5   | Complete | 2026-05     |
| 3. Runtime Contract + Drill Mode                   | v1.0      | 9/9   | Complete | 2026-05     |
| 4. Storage + Workloads-Scheduling Packs            | v1.0      | 18/18 | Complete | 2026-05     |
| 5. Services-Networking + Cluster-Architecture      | v1.0      | 20/20 | Complete | 2026-05     |
| 6. Troubleshooting Pack                            | v1.0      | 9/9   | Complete | 2026-05-13  |
| 7. Exam Mode + Blueprint Alpha + Reporting         | v1.0      | 7/7   | Complete | 2026-05-15  |
| 07.1. Grading Honesty Rebuild                      | v1.0      | 13/13 | Complete | 2026-05-17  |
| 8. Blueprint Bravo + Banners + Docs + CI           | v1.0      | 5/5   | Complete | 2026-05-14  |
| 10. HIGH Single-Question Edits                     | v1.0.1    | 4/4   | Complete | 2026-05-17  |
| 11. HIGH Grader/Question Rework                    | v1.0.1    | 2/2   | Complete | 2026-05-17  |
| 12. Trap-Coverage Lint + Orphan Cleanup            | v1.0.1    | 5/5   | Complete | 2026-05-17  |
| 13. Grader-Strengthening                           | v1.0.1    | 3/3   | Complete | 2026-05-17  |
| 14. Question Framing + Library Fixes               | v1.0.1    | 4/4   | Complete | 2026-05-17  |
| 15. Live-Cluster Symptom-Diff CI                   | v1.0.1    | 7/7   | Complete | 2026-05-17  |
