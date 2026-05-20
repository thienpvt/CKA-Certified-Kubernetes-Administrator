# Roadmap: CKA Certified Kubernetes Administrator

## Milestones

- ✅ **v1.0 CKA Exam Simulator MVP** — Phases 1-8 + 07.1 (shipped 2026-05-17)
- ✅ **v1.0.1 Full Audit Remediation** — Phases 10-15 (shipped 2026-05-18, tech_debt; live UAT closed 2026-05-19)
- ✅ **v1.0.2 Question Correctness Audit + Backlog Cleanup** — Phases 16-21 (shipped 2026-05-20, tech_debt; GHA bash-tests environmental reds routed to v1.0.3 BLG-07)
- 📋 **v1.0.3** — Not yet planned (BLG-06 per-finding triage + BLG-07 GHA bash-tests delta — `/gsd-new-milestone` to start)

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

### 🚧 v1.0.2 Question Correctness Audit + Backlog Cleanup (In Progress)

**Milestone Goal:** Every question in every pack reaches its prose-claimed end state when `setup.sh` runs (audited via the new question-intent baseline), every Phase 15 GHA failure pattern is closed at the root, and the FORENSIC-v102.md ledger is signed off as fully closed.

- [ ] **Phase 16: Question-Intent Baseline Harness** — Ship `cka-sim audit` + per-question `intent.yaml` for all 38 domain questions and 34 mock framings; document the third audit-only artifact in `docs/AUTHORING.md`.
- [ ] **Phase 17: v1.0.2 Backlog Cleanup** — Close every Phase 15 GHA first-run failure pattern (A/B/C/D), the 2 unit-suite reds, and the CI shellcheck red. Parallel-eligible with Phase 16.
- [ ] **Phase 18: Forensic Re-Audit (Blind)** — Run `cka-sim audit` over all 38 domain-pack + 34 mock framings; publish `FORENSIC-v102.md` ledger that drives remediation phase shape.
- [ ] **Phase 19: HIGH-Severity Remediation (Placeholder)** — Close every HIGH finding from FORENSIC-v102.md. Concrete sub-phases (19.1, 19.2, ...) inserted via `/gsd-phase --insert` after Phase 18 ships.
- [ ] **Phase 20: MED-Severity Remediation (Placeholder)** — Close every MED finding via grader strengthening, framing reconciliation, and library corrections. Sub-phases inserted post-Phase 18.
- [ ] **Phase 21: Post-Fix Intent Re-Verification + Milestone Sign-Off** — Re-run `cka-sim audit` over every remediated question, sign off FORENSIC-v102.md as fully closed, batch live drill UATs.

### 📋 v1.0.3 (Not yet planned)

Two outstanding tech-debt items routed from v1.0.2 close-out:
- **BLG-06** — Per-finding shellcheck/yamllint triage. `continue-on-error: true` scaffolded in P17 awaits per-finding fixes per Plan 17-05's documented flow.
- **BLG-07** — GHA bash-tests environmental reds. 9 unit-test cases fail on `ubuntu-latest` runners but pass on Docker Ubuntu 22.04 + 24.04 + Windows MSYS. Surfaced after Phase 17 fixed `tests/run.sh` exec-bit. Symptom: `expected 1 got 0` on `cka_sim::baseline::is_candidate_modified` unchanged-baseline branch. Investigate runner-specific environmental delta (jq version, locale, `set -u` interaction).

Use `/gsd-new-milestone` to scope and plan.

## Phase Details

### Phase 16: Question-Intent Baseline Harness
**Goal**: Authors and the audit harness share a single source of truth — every question's `intent.yaml` faithfully encodes its `question.md` prose, and `cka-sim audit` diffs intent against actual cluster state on a clean kind+Calico cluster.
**Depends on**: v1.0.1 shipped
**Parallel-eligible with**: Phase 17 (independent dependency chains — harness is greenfield, backlog is pre-traced fixes)
**Requirements**: BASELINE-01, BASELINE-02, BASELINE-03, BASELINE-04, DOC-01
**Success Criteria** (what must be TRUE):
  1. `cka-sim audit <pack> <question>` runs `setup.sh` against a clean kind+Calico cluster, captures actual post-setup state, and emits a human-readable diff with `question-id × claimed-state × actual-state × verdict` columns.
  2. All 38 domain-pack questions ship a committed `intent.yaml` reviewer-verifiable against its `question.md` prose — a reader of the prose and the YAML agrees the YAML faithfully encodes the prose.
  3. Both mock exam packs (blueprint-alpha 17 + blueprint-bravo 17 = 34 framings) ship per-framing `intent.yaml` separate from domain-pack baselines, enabling detection of framing-drift bugs where a mock reframes a domain-pack question.
  4. `docs/AUTHORING.md` documents the `intent.yaml` schema, the audit-only role, and the full triplet of test artifacts (`intent.yaml` / `expected-symptom.yaml` / `lib/baseline.sh` snapshot); a new question author can read the doc and ship a passing `intent.yaml` without further guidance.
  5. The audit harness is intentionally NOT wired to GHA `validate.yml`; `cka-sim audit` is a one-shot forensic operation re-run during forensic phases, not an ongoing CI gate.
**Plans**: TBD

### Phase 17: v1.0.2 Backlog Cleanup
**Goal**: Every Phase 15 GHA first-run failure pattern (A through D) is closed at the root, the 2 pre-existing unit-suite reds are root-caused and fixed, and the CI shellcheck job is green on Linux. Pre-traced from STATE.md `v1.0.2 Backlog` section, GHA run `26070172071` against kind+Calico, head_sha `af493ce`.
**Depends on**: v1.0.1 shipped
**Parallel-eligible with**: Phase 16
**Requirements**: BLG-01, BLG-02, BLG-03, BLG-04, BLG-05, BLG-06
**Success Criteria** (what must be TRUE):
  1. Pattern A closed: GHA `symptom-diff` job runs end-to-end against kind+Calico with zero `${CKA_SIM_LAB_NS}` placeholder-substitution failures across all 12 affected expected-symptom YAMLs (cluster-architecture/{03,04,05,06,07}, services-networking/05, troubleshooting/{04,05,06}, workloads-scheduling/05 + 2 more).
  2. Pattern B closed: the 3 setup-failing-on-kind questions (cluster-architecture/02-etcd-backup-restore, storage/04-csi-volumesnapshot, workloads-scheduling/06-static-pod) either ship via an `unsupported-on-kind` mechanism honored by the lint harness, or pass via kind-specific setup variants.
  3. Pattern C closed: storage/01-pvc-binding and cluster-architecture/08-priorityclass expected-symptom YAMLs are regenerated against post-Phase-10 reality; symptom-diff against HEAD passes for both.
  4. Pattern D closed: Calico-on-kind Deployment-Available timeout resolved for all 3 affected questions (troubleshooting/02-netpol-dns-egress, workloads-scheduling/01-deployment-requests, workloads-scheduling/07-native-sidecar) via timeout extension, converge-then-check pre-step, or relaxed Available expectation; lint passes deterministically across 5 consecutive runs.
  5. `cka-sim/scripts/test.sh` unit suite returns 0 reds (storage/02-storageclass-dynamic and workloads-scheduling/05-daemonset graders root-caused as either grader regression or fixture drift, then fixed at root cause).
  6. CI `shellcheck` job exits 0 on the cka-sim corpus on Linux — first-run reds either fixed in code or the lint config is intentionally relaxed with documented rationale in the phase SUMMARY.
**Plans**: TBD

### Phase 18: Forensic Re-Audit (Blind)
**Goal**: A complete bug ledger (`.planning/forensics/FORENSIC-v102.md`) classifies every question intent-vs-actual divergence by severity and root-cause class, and that ledger — not pre-baked guesses — drives the structure and content of the remediation phases inserted next.
**Depends on**: Phase 16 (needs `cka-sim audit` + `intent.yaml` corpus), Phase 17 (clean lint baseline so audit signal isn't drowned in known-noise patterns)
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03, AUDIT-04
**Success Criteria** (what must be TRUE):
  1. All 38 domain-pack questions audited via `cka-sim audit`; every intent-vs-actual diff is recorded with severity (HIGH/MED/LOW) and root-cause class (`setup-drift` / `question-prose-wrong` / `framing-mismatch` / `grader-disagrees`).
  2. Both mock exam packs (blueprint-alpha + blueprint-bravo, 34 framings total) audited against their own `intent.yaml`; framing-drift bugs — where a mock reframes a domain-pack question and the reframe disagrees with what the underlying setup produces — are surfaced in a comparable ledger.
  3. `.planning/forensics/FORENSIC-v102.md` is published with `question-id × bug-class × severity × suggested-fix` columns, comparable in shape to v1.0.1's `forensics/report-20260517-091657-full-audit.md`.
  4. Remediation Phases 19 and 20 (placeholder slots) have concrete decimal sub-phases (19.1, 19.2, ..., 20.1, 20.2, ...) inserted via `/gsd-phase --insert`, each declaring its own BUG-* requirements derived from FORENSIC-v102.md (no bug-IDs pre-baked in this roadmap).
**Plans**: TBD

### Phase 19: HIGH-Severity Remediation (Placeholder)
**Goal**: Every HIGH-severity finding from FORENSIC-v102.md is closed in code, and ref-solutions for affected questions still score max/max under any reworked graders. **This is a placeholder phase** — concrete plans, BUG-* requirements, and decimal sub-phases (19.1, 19.2, ...) are generated from the ledger via `/gsd-phase --insert` after Phase 18 ships.
**Depends on**: Phase 18 (needs FORENSIC-v102.md ledger)
**Requirements**: REMEDIATE-01
**Success Criteria** (what must be TRUE):
  1. Every HIGH-severity entry in FORENSIC-v102.md is traced to a closed BUG-* requirement in a 19.x sub-phase; ledger entries carry `closed-by` commit references.
  2. Each 19.x sub-phase mirrors v1.0.1's P10/P11 shape — HIGH single-question edits and HIGH grader/question rework — with per-bug evidence captured in the sub-phase SUMMARY.md.
  3. Ref-solutions for every affected question still score max/max under reworked graders.
  4. Empty-submission scores remain 0/100 for every affected question (no Phase 07.1 grading-honesty leak introduced by the rework).
**Plans**: 19.1, 19.2 (inserted from FORENSIC-v102.md 2026-05-20)

### Phase 19.1: BUG-H07 Close — locale-safe grep in static-pod-manifest setup
**Goal**: Replace `grep -P '\t'` in `cka-sim/packs/troubleshooting/05-static-pod-manifest/setup.sh` with a locale-independent shape so setup.sh succeeds on Linux GHA runners with non-UTF-8 locales (the failure surfaced as the only ERROR in Phase 18's audit).
**Depends on**: Phase 18 (FORENSIC-v102.md identifies BUG-H07)
**Requirements**: BUG-H07
**Success Criteria**:
  1. `bash cka-sim/packs/troubleshooting/05-static-pod-manifest/setup.sh` exits 0 on a GHA Ubuntu runner without explicit `LC_ALL` set.
  2. `cka-sim audit troubleshooting/05-static-pod-manifest` returns PASS on kind+Calico.
  3. Empty submission for the question still scores 0/N (no grading-honesty regression).

### Phase 19.2: BUG-H08 Close — audit-policy grader vs fixture drift
**Goal**: Reconcile `cka-sim/packs/cluster-architecture/05-audit-policy/grade.sh` with the case-file's authoritative `expected_empty_score=0/1`. Either reduce grader to 1 assertion OR update the unit-test case to match the grader's 4 assertions. Same fixture-vs-grader-drift class as v1.0.1's BLG-05.
**Depends on**: Phase 18
**Requirements**: BUG-H08
**Success Criteria**:
  1. `bash cka-sim/scripts/test.sh` returns 0 on Linux with `cluster-architecture__05-audit-policy` PASSING.
  2. Ref-solution still scores max/max.
  3. Empty submission scores 0/N (where N is whatever total the reconciliation lands on).

### Phase 20: MED-Severity Remediation (Placeholder)
**Goal**: Every MED-severity finding from FORENSIC-v102.md is closed via grader strengthening, framing reconciliation, or library-level corrections. **Placeholder phase** — concrete plans inserted via `/gsd-phase --insert` post-Phase 18.
**Depends on**: Phase 19
**Requirements**: REMEDIATE-02
**Success Criteria** (what must be TRUE):
  1. Every MED-severity entry in FORENSIC-v102.md is traced to a closed BUG-* requirement in a 20.x sub-phase; ledger entries carry `closed-by` commit references.
  2. Each 20.x sub-phase mirrors v1.0.1's P13/P14 shape — grader strengthening with precise-value assertions, framing reconciliation between question.md and setup output, and library typos.
  3. Strengthened graders still score ref-solutions max/max.
  4. No HIGH-severity bug regressions introduced — Phase 19 invariants (max/max ref-solution, 0/100 empty) preserved across the MED remediation set.
**Plans**: 20.1, 20.2 (inserted from FORENSIC-v102.md 2026-05-20)

### Phase 20.1: BUG-M11 Close — harness label extraction edge case
**Goal**: Investigate why `cka-sim/lib/symptom-diff.sh`'s `_jsonpath_to_jq` for `metadata.labels.X` paths returns a JSON-array string `[\n  "restricted"\n]` instead of a scalar `restricted` for cluster-architecture/04-pss-enforce. Fix in the harness; verify with the existing unit cases.
**Depends on**: Phase 18, Phase 19
**Requirements**: BUG-M11
**Success Criteria**:
  1. `cka-sim audit cluster-architecture/04-pss-enforce` returns PASS on kind+Calico.
  2. `bash cka-sim/scripts/test.sh` continues to return 0 (no regression to existing 88 cases).
  3. Existing label-bearing audits (other PASS questions with metadata.labels claims) remain PASS.

### Phase 20.2: BUG-M12 Close — exam-mode report_golden re-baseline
**Goal**: Re-baseline `cka-sim/tests/fixtures/exam/expected-report.md` against current exam-mode rendering. Investigate the diff (numeric formatting, table widths, locale, etc.); either update the fixture if the new output is correct, or fix the renderer if the fixture was authoritative.
**Depends on**: Phase 19
**Requirements**: BUG-M12
**Success Criteria**:
  1. `bash cka-sim/scripts/test.sh` returns 0 on Linux with `report_golden` PASSING.
  2. Per-domain score table format remains stable across local + Linux CI runs.

### Phase 21: Post-Fix Intent Re-Verification + Milestone Sign-Off
**Goal**: Every remediated question's `intent.yaml` is re-verified against its post-fix `setup.sh` via `cka-sim audit`, the FORENSIC-v102.md ledger is signed off as fully closed, and the v1.0.2 milestone audit captures the final per-requirement status.
**Depends on**: Phase 20
**Requirements**: REMEDIATE-03
**Success Criteria** (what must be TRUE):
  1. `cka-sim audit` against every remediated question (HIGH from Phase 19 + MED from Phase 20) emits an empty intent-vs-actual diff; the audit summary table is archived in the phase SUMMARY.
  2. `.planning/forensics/FORENSIC-v102.md` is updated with closure status per bug; every entry carries a `closed-by` commit reference and a final verdict (`closed` or `accepted-as-out-of-scope`).
  3. Live drill UATs are executed against the v1.0.2 lab cluster for every remediated question, batched at milestone close (mirrors v1.0.1's P10/P11/P13 UAT pattern; no local kubectl required during phase execution).
  4. `.planning/milestones/v1.0.2-MILESTONE-AUDIT.md` records final status per requirement (satisfied / addressed / deferred), with phase-by-phase commit ranges comparable to v1.0.1's audit.
**Plans**: TBD

## Progress

**Execution Order:** Integer phases run in numeric order: 16 → 17 → 18 → 19 → 20 → 21. Phases 16 and 17 are parallel-eligible (independent dependency chains). Decimal sub-phases inserted into 19 and 20 post-Phase 18 execute as 19.1 → 19.2 → ... → 20.1 → 20.2 → ... before Phase 21.

**Verification model:** Unit (`cka-sim/scripts/test.sh`) + lint (`lint-packs.sh`, `lint-traps.sh`, `lint-coverage.sh`, `lint-trap-coverage.sh`, `lint-question-symptom.sh`) + GHA `validate.yml` (kind+Calico) during phases. Live drill UATs batched at milestone close (same pattern as v1.0.1). No local kubectl required.

| Phase                                              | Milestone | Plans | Status      | Completed   |
| -------------------------------------------------- | --------- | ----- | ----------- | ----------- |
| 1. Cluster Bootstrap + Runner Skeleton             | v1.0      | 2/2   | Complete    | 2026-05     |
| 2. Trap Framework + Assertion Library              | v1.0      | 5/5   | Complete    | 2026-05     |
| 3. Runtime Contract + Drill Mode                   | v1.0      | 9/9   | Complete    | 2026-05     |
| 4. Storage + Workloads-Scheduling Packs            | v1.0      | 18/18 | Complete    | 2026-05     |
| 5. Services-Networking + Cluster-Architecture      | v1.0      | 20/20 | Complete    | 2026-05     |
| 6. Troubleshooting Pack                            | v1.0      | 9/9   | Complete    | 2026-05-13  |
| 7. Exam Mode + Blueprint Alpha + Reporting         | v1.0      | 7/7   | Complete    | 2026-05-15  |
| 07.1. Grading Honesty Rebuild                      | v1.0      | 13/13 | Complete    | 2026-05-17  |
| 8. Blueprint Bravo + Banners + Docs + CI           | v1.0      | 5/5   | Complete    | 2026-05-14  |
| 10. HIGH Single-Question Edits                     | v1.0.1    | 4/4   | Complete    | 2026-05-17  |
| 11. HIGH Grader/Question Rework                    | v1.0.1    | 2/2   | Complete    | 2026-05-17  |
| 12. Trap-Coverage Lint + Orphan Cleanup            | v1.0.1    | 5/5   | Complete    | 2026-05-17  |
| 13. Grader-Strengthening                           | v1.0.1    | 3/3   | Complete    | 2026-05-17  |
| 14. Question Framing + Library Fixes               | v1.0.1    | 4/4   | Complete    | 2026-05-17  |
| 15. Live-Cluster Symptom-Diff CI                   | v1.0.1    | 7/7   | Complete    | 2026-05-17  |
| 16. Question-Intent Baseline Harness               | v1.0.2    | 0/TBD | Not started | -           |
| 17. v1.0.2 Backlog Cleanup                         | v1.0.2    | 0/TBD | Not started | -           |
| 18. Forensic Re-Audit (Blind)                      | v1.0.2    | 2/2   | Complete    | 2026-05-20  |
| 19. HIGH-Severity Remediation (Placeholder)        | v1.0.2    | 0/2   | Not started | -           |
| 19.1. BUG-H07 locale-safe grep                     | v1.0.2    | 0/TBD | Not started | -           |
| 19.2. BUG-H08 audit-policy grader vs fixture       | v1.0.2    | 0/TBD | Not started | -           |
| 20. MED-Severity Remediation (Placeholder)         | v1.0.2    | 0/2   | Not started | -           |
| 20.1. BUG-M11 harness label extraction             | v1.0.2    | 0/TBD | Not started | -           |
| 20.2. BUG-M12 report_golden re-baseline            | v1.0.2    | 0/TBD | Not started | -           |
| 21. Post-Fix Intent Re-Verification + Sign-Off     | v1.0.2    | 0/TBD | Not started | -           |
