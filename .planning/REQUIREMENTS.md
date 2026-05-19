# Requirements: CKA Exam Simulator — v1.0.2 Question Correctness Audit + Backlog Cleanup

**Defined:** 2026-05-19
**Core Value:** A candidate can take a 2-hour timed mock exam against their own cluster and get an honest, trap-aware score telling them exactly which CKA domains and which classes of mistake they need to drill before sitting the real exam.

**Driven by:**
- v1.0.1 left 6 v1.0.2 backlog items from Phase 15 GHA first run (`STATE.md` v1.0.2 Backlog section, GHA run `26070172071`).
- User reports questions still scoring or behaving incorrectly after v1.0.1 ship — specifically: question.md prose says one thing ("consumer pod in pending state") but `setup.sh` produces a different state (pod is Running). Phase 15's `expected-symptom.yaml` only catches *regressions* against what setup currently produces; it cannot catch a question whose prose disagreed with setup from day one.
- v1.0.2 introduces a third audit-only artifact — the **question-intent baseline** — derived from question.md prose, not from running anything. The audit then runs `setup.sh` for real and diffs actual cluster state against the declared intent.

## v1.0.2 Requirements

### Audit Harness — Question-Intent Baseline

New audit-only test artifact derived from `question.md` prose. The polarity is intent → reality: hand-authored YAML captures *what the question claims the candidate will see after setup*; the audit harness runs `setup.sh` and diffs. NOT shipped to candidates. NOT wired to GHA `validate.yml` (audit-only — re-run during forensic phases). Distinct from Phase 15's `expected-symptom.yaml` (which captures actual post-setup state and only catches regressions).

- [ ] **BASELINE-01**: A `cka-sim audit <pack> <q>` (or `scripts/audit-question.sh`) entry point runs `setup.sh` against a clean kind+Calico cluster, captures actual post-setup state, and diffs against the hand-authored `intent.yaml` for that question. Diff output is human-readable with question-id × claimed-state × actual-state × verdict columns.
- [ ] **BASELINE-02**: Every question across 5 domain packs (38 questions) has a committed `intent.yaml` hand-authored from its `question.md` prose. The acceptance criterion is reviewer-verifiable: a reader of `question.md` and `intent.yaml` agrees the YAML faithfully encodes the prose.
- [ ] **BASELINE-03**: Both mock exam packs (blueprint-alpha 17 questions, blueprint-bravo 17 questions) have their own committed `intent.yaml` per question — separate from domain-pack baselines. Catches framing-drift bugs where a mock question reframes a domain-pack question with different prose.
- [ ] **BASELINE-04**: `intent.yaml` schema and the audit-only role documented in `docs/AUTHORING.md` (or `docs/SCHEMA.md`). New question authors know the full triplet of test artifacts: `intent.yaml` (question-prose-state, audit-only), `expected-symptom.yaml` (actual-post-setup-state, CI-checked), `lib/baseline.sh` snapshot (pre-candidate-state, runtime grading).

### Forensic Re-Audit (Blind)

Every question audited against v1.35 blueprint AND its question-intent baseline (BASELINE-02 / BASELINE-03). No prior knowledge of which questions are wrong; output is the bug ledger that drives remediation phases.

- [ ] **AUDIT-01**: All 38 domain-pack questions audited via `cka-sim audit` (BASELINE-01); intent-vs-actual diffs recorded with severity (HIGH / MED / LOW) and root-cause classification (setup-drift / question-prose-wrong / framing-mismatch / grader-disagrees).
- [ ] **AUDIT-02**: Both mock exam packs (blueprint-alpha 17, blueprint-bravo 17) audited against their own `intent.yaml` (BASELINE-03); framing-drift bugs surfaced where a mock reframes a domain-pack question and the reframe disagrees with what the underlying setup produces.
- [ ] **AUDIT-03**: `FORENSIC-v102.md` ledger published in `.planning/forensics/` with question-id × bug-class × severity × suggested fix, comparable to the v1.0.1 forensic report shape.
- [ ] **AUDIT-04**: Forensic ledger informs which remediation phases are inserted; phase plan is generated from the ledger via `/gsd-phase --insert` after audit lands (not pre-baked in this roadmap).

### Severity-Grouped Remediation

Phase plan derived from the AUDIT-03 ledger; this roadmap reserves remediation slots but does not pre-bake bug-IDs. Each remediation phase will define its own BUG-* requirements when inserted.

- [ ] **REMEDIATE-01**: All HIGH-severity findings from AUDIT-03 closed in code (single-question edits or grader rework). Phase shape mirrors v1.0.1 P10/P11.
- [ ] **REMEDIATE-02**: All MED-severity findings from AUDIT-03 closed in code (grader strengthening, framing fixes, library typos). Phase shape mirrors v1.0.1 P13/P14.
- [ ] **REMEDIATE-03**: Every fixed question's `intent.yaml` re-verified against the post-fix `setup.sh` via `cka-sim audit`; intent-vs-actual diff is empty for all remediated questions.

### v1.0.2 Backlog Cleanup (from Phase 15 first-run)

Pre-traced findings carried from STATE.md `v1.0.2 Backlog` section. GHA run `26070172071` against kind+Calico, head_sha `af493ce`.

- [ ] **BLG-01**: Symptom-diff Pattern A — unsubstituted `${CKA_SIM_LAB_NS}` placeholder in 12 expected-symptom YAMLs. Lint harness expands the placeholder before comparison (or YAMLs rewritten to use lint namespace). Affected: cluster-architecture/{03,04,05,06,07}, services-networking/05, troubleshooting/{04,05,06}, workloads-scheduling/05, plus 2 more.
- [ ] **BLG-02**: Symptom-diff Pattern B — `setup.sh` failed against the kind lint sandbox for 3 questions (cluster-architecture/02-etcd-backup-restore, storage/04-csi-volumesnapshot, workloads-scheduling/06-static-pod). Either an `unsupported-on-kind` exclusion list lands, or kind-specific setup variants ship.
- [ ] **BLG-03**: Symptom-diff Pattern C — Phase 10 collateral expected-symptom drift (storage/01-pvc-binding from BUG-H01 reshape; cluster-architecture/08-priorityclass from BUG-H04 unset-bool jsonpath). Affected expected-symptom YAMLs regenerated.
- [ ] **BLG-04**: Symptom-diff Pattern D — Calico-on-kind Deployment-Available timeout (3 questions: troubleshooting/02-netpol-dns-egress, workloads-scheduling/01-deployment-requests, workloads-scheduling/07-native-sidecar). Lint harness extends timeout, adds converge-then-check pre-step, or relaxes Available expectation.
- [ ] **BLG-05**: 2 unit-suite reds: `storage__02-storageclass-dynamic` (ref 0/1 vs 1/1) and `workloads-scheduling__05-daemonset` (ref 3/4 vs 4/4). Investigate grader regression vs fixture drift; fix root cause; unit suite back to fully green.
- [ ] **BLG-06**: CI shellcheck job red on the cka-sim corpus (first run after Phase 15 lint enabled it on Linux). Investigate scope, decide to fix or relax lint config; CI shellcheck job green.

### Documentation

- [ ] **DOC-01**: `docs/AUTHORING.md` updated with the question-intent baseline workflow and `cka-sim audit` invocation. New question authors know the full triplet of test artifacts: `intent.yaml` (question-prose-state, audit-only), `expected-symptom.yaml` (actual-post-setup-state, CI-checked), `lib/baseline.sh` snapshot (pre-candidate-state, runtime grading).

## Future Requirements

Carried forward from v1.0 / v1.0.1 — not in v1.0.2 scope.

- Domain coverage gap closure — file-baseline support for etcd snapshot, audit-policy YAML, node-level files
- Real-cluster CI — github-hosted runner that spins up a kind/k3s cluster and runs full `score == max` ref-solution UAT for every question (BLG-05's symptom-diff is a narrower variant)
- Quality-of-life: aliases, kubectl-neat integration, time-tracking per question
- 9 live-cluster drill UAT runs from v1.0.1 — already executed and green (2026-05-18); no v1.0.2 work item

## Out of Scope

| Feature | Reason |
|---------|--------|
| New questions / coverage expansion | Different milestone — v1.0.2 is correctness, not coverage |
| Migrating cka-sim corpus from bash to Go/Python | Tech stack constraint (pure bash); deferred to v2.0+ |
| Reworking the 47-entry trap catalog itself | Catalog is correct; v1.0.2 only fixes per-question correctness |
| Auto-fix for AUDIT-03 findings | Manual remediation per phase; auto-fix would mask root-cause classes |
| Replacing `lib/baseline.sh` setup-state mechanism | Setup-state baseline (Phase 07.1) is correct as shipped; v1.0.2 ADDS question-intent baseline, doesn't replace candidate-state |
| Mock-exam pack content authoring | Mocks compose from packs by reference; BASELINE-03 / AUDIT-02 only audit framing prose, not author new mock questions |
| Wiring `cka-sim audit` to GHA `validate.yml` | Audit is intentionally one-shot, run during forensic phases. Future drift caught by Phase 15's `expected-symptom.yaml` lint, not by intent baseline. Ongoing-CI variant deferred to v1.0.3+ |
| Local kubectl install on author machine | Not required; GHA `validate.yml` (kind+Calico) is the live-cluster CI |

## Traceability

Each requirement maps to exactly one phase. Sub-phase BUG-* requirements for Phases 19/20 are generated from FORENSIC-v102.md via `/gsd-phase --insert` after Phase 18 ships.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BASELINE-01 | Phase 16 | Pending |
| BASELINE-02 | Phase 16 | Pending |
| BASELINE-03 | Phase 16 | Pending |
| BASELINE-04 | Phase 16 | Pending |
| DOC-01 | Phase 16 | Pending |
| BLG-01 | Phase 17 | Pending |
| BLG-02 | Phase 17 | Pending |
| BLG-03 | Phase 17 | Pending |
| BLG-04 | Phase 17 | Pending |
| BLG-05 | Phase 17 | Pending |
| BLG-06 | Phase 17 | Pending |
| AUDIT-01 | Phase 18 | Pending |
| AUDIT-02 | Phase 18 | Pending |
| AUDIT-03 | Phase 18 | Pending |
| AUDIT-04 | Phase 18 | Pending |
| REMEDIATE-01 | Phase 19 | Pending |
| REMEDIATE-02 | Phase 20 | Pending |
| REMEDIATE-03 | Phase 21 | Pending |

**Coverage:**
- v1.0.2 requirements: 18 total
- Mapped to phases: 18 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-05-19*
*Last updated: 2026-05-19 — roadmap landed; traceability filled by gsd-roadmapper*
