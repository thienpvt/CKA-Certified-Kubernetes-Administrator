# Requirements: CKA Exam Simulator — v1.0.2 Question Correctness Audit + Backlog Cleanup

**Defined:** 2026-05-19
**Core Value:** A candidate can take a 2-hour timed mock exam against their own cluster and get an honest, trap-aware score telling them exactly which CKA domains and which classes of mistake they need to drill before sitting the real exam.

**Driven by:**
- v1.0.1 left 6 v1.0.2 backlog items from Phase 15 GHA first run (`STATE.md` v1.0.2 Backlog section, GHA run `26070172071`).
- User reports questions still scoring or behaving incorrectly after v1.0.1 ship — specifically: question.md prose says one thing ("consumer pod in pending state") but `setup.sh` produces a different state (pod is Running). Phase 15's `expected-symptom.yaml` only catches *regressions* against what setup currently produces; it cannot catch a question whose prose disagreed with setup from day one.
- v1.0.2 introduces a third audit-only artifact — the **question-intent baseline** — derived from question.md prose, not from running anything. The audit then runs `setup.sh` for real and diffs actual cluster state against the declared intent.

## v1.0.2 Requirements

### Audit Harness — Question-Intent Baseline

**Re-scoped 2026-05-19 during `/gsd-discuss-phase 16`:** the question-intent baseline artifact already ships as Phase 15's `expected-symptom.yaml` (per-question YAML, hand-derived from `question.md` prose, lint-checked by `cka-sim/scripts/lint-question-symptom.sh`). All 34 domain questions already have a committed YAML. The schema is documented at `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md`.

What's actually missing for v1.0.2: an audit-mode tool with human-readable diff output for forensic triage (the existing lint emits CI-style 0/1 only), an `AUTHORING.md` workflow guide, and the prose-fidelity discipline check (executed in Phase 18 by reading each `question.md` + `expected-symptom.yaml` pair side-by-side). NOT shipped to candidates. NOT wired to GHA `validate.yml` (audit-only — re-run during forensic phases).

- [ ] **BASELINE-01**: `cka-sim audit` subcommand (lib/cmd/audit.sh) accepts three scopes — `cka-sim audit <pack>/<q>` | `cka-sim audit <pack>` | `cka-sim audit` (all 34) — runs `setup.sh` against a clean kind+Calico cluster, captures actual post-setup state, and emits a human-readable flat table per question (columns: question, resource, jsonpath, claimed, actual, verdict). Each question's diff includes a `Claim source:` block with question.md prose excerpts. PASS prints a one-line `✓ <id>: PASS (N/N expectations met)`. Aggregate summary at end: `N/34 PASS, M FAIL, K errors`. `--report path/to.md` flag persists the same content to markdown.
- [ ] **BASELINE-04**: `docs/AUTHORING.md` updated with the `cka-sim audit` workflow, the test-artifact triplet (`expected-symptom.yaml` / `lib/baseline.sh` snapshot / `lib/grade.sh`), and a worked example showing how to author a new question's `expected-symptom.yaml` from `question.md` prose. Cross-links to `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` (schema) and `cka-sim/lib/GRADING-HONESTY.md` (candidate-state baseline). Discoverable from cka-sim/README.md.

**Removed from this milestone:**

- ~~BASELINE-02 (commit per-question intent.yaml for 38 domain questions)~~ — N/A: 34 questions (not 38; PROJECT.md count is wrong) already have `expected-symptom.yaml` from Phase 15. Prose-fidelity is audited manually in Phase 18, not coverage-authored in Phase 16.
- ~~BASELINE-03 (commit per-framing intent.yaml for 34 mock framings)~~ — N/A: blueprint manifests at `exams/blueprint-{alpha,bravo}/manifest.yaml` are `(pack, slug)` reference lists, not reframed prose. Mocks resolve to domain-pack `question.md` at runtime — no per-mock prose to baseline.

### Forensic Re-Audit (Blind)

Every question audited against v1.35 blueprint AND its question-intent baseline (BASELINE-02 / BASELINE-03). No prior knowledge of which questions are wrong; output is the bug ledger that drives remediation phases.

- [ ] **AUDIT-01**: All 34 domain-pack questions audited via `cka-sim audit`; intent-vs-actual diffs recorded with severity (HIGH / MED / LOW) and root-cause classification (setup-drift / question-prose-wrong / framing-mismatch / grader-disagrees). Each finding also carries a prose-fidelity verdict (faithful / drifted / ambiguous) from a manual question.md + expected-symptom.yaml side-by-side review.
- [ ] **AUDIT-02**: Both mock exam packs (blueprint-alpha 17, blueprint-bravo 17) cross-checked against their domain-pack source questions. Manifests are reference-only `(pack, slug)` lists — verify each reference resolves to a passing domain-pack audit. No separate mock-prose review required.
- [ ] **AUDIT-03**: `FORENSIC-v102.md` ledger published in `.planning/forensics/` with question-id × bug-class × severity × suggested fix, comparable to the v1.0.1 forensic report shape.
- [ ] **AUDIT-04**: Forensic ledger informs which remediation phases are inserted; phase plan is generated from the ledger via `/gsd-phase --insert` after audit lands (not pre-baked in this roadmap).

### Severity-Grouped Remediation

Phase plan derived from the AUDIT-03 ledger; this roadmap reserves remediation slots but does not pre-bake bug-IDs. Each remediation phase will define its own BUG-* requirements when inserted.

- [ ] **REMEDIATE-01**: All HIGH-severity findings from AUDIT-03 closed in code (single-question edits or grader rework). Phase shape mirrors v1.0.1 P10/P11.
- [ ] **REMEDIATE-02**: All MED-severity findings from AUDIT-03 closed in code (grader strengthening, framing fixes, library typos). Phase shape mirrors v1.0.1 P13/P14.
- [ ] **REMEDIATE-03**: Every fixed question's `expected-symptom.yaml` re-verified against the post-fix `setup.sh` via `cka-sim audit`; intent-vs-actual diff is empty for all remediated questions.

### v1.0.2 Backlog Cleanup (from Phase 15 first-run)

Pre-traced findings carried from STATE.md `v1.0.2 Backlog` section. GHA run `26070172071` against kind+Calico, head_sha `af493ce`.

- [ ] **BLG-01**: Symptom-diff Pattern A — unsubstituted `${CKA_SIM_LAB_NS}` placeholder in 12 expected-symptom YAMLs. Lint harness expands the placeholder before comparison (or YAMLs rewritten to use lint namespace). Affected: cluster-architecture/{03,04,05,06,07}, services-networking/05, troubleshooting/{04,05,06}, workloads-scheduling/05, plus 2 more.
- [ ] **BLG-02**: Symptom-diff Pattern B — `setup.sh` failed against the kind lint sandbox for 3 questions (cluster-architecture/02-etcd-backup-restore, storage/04-csi-volumesnapshot, workloads-scheduling/06-static-pod). Either an `unsupported-on-kind` exclusion list lands, or kind-specific setup variants ship.
- [ ] **BLG-03**: Symptom-diff Pattern C — Phase 10 collateral expected-symptom drift (storage/01-pvc-binding from BUG-H01 reshape; cluster-architecture/08-priorityclass from BUG-H04 unset-bool jsonpath). Affected expected-symptom YAMLs regenerated.
- [ ] **BLG-04**: Symptom-diff Pattern D — Calico-on-kind Deployment-Available timeout (3 questions: troubleshooting/02-netpol-dns-egress, workloads-scheduling/01-deployment-requests, workloads-scheduling/07-native-sidecar). Lint harness extends timeout, adds converge-then-check pre-step, or relaxes Available expectation.
- [ ] **BLG-05**: 2 unit-suite reds: `storage__02-storageclass-dynamic` (ref 0/1 vs 1/1) and `workloads-scheduling__05-daemonset` (ref 3/4 vs 4/4). Investigate grader regression vs fixture drift; fix root cause; unit suite back to fully green.
- [ ] **BLG-06**: CI shellcheck job red on the cka-sim corpus (first run after Phase 15 lint enabled it on Linux). Investigate scope, decide to fix or relax lint config; CI shellcheck job green.

### Documentation

- [ ] **DOC-01**: Subsumed by **BASELINE-04** above. (Original DOC-01: AUTHORING.md update — folded into BASELINE-04 since they describe the same artifact.)

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
| BASELINE-02 | — | Removed (already shipped Phase 15) |
| BASELINE-03 | — | Removed (mocks reference-only — see ### Audit Harness note) |
| BASELINE-04 | Phase 16 | Pending |
| DOC-01 | Phase 16 | Folded into BASELINE-04 |
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
- v1.0.2 active requirements: 15 total (was 18; BASELINE-02 / BASELINE-03 removed during `/gsd-discuss-phase 16` reframing; DOC-01 folded into BASELINE-04)
- Mapped to phases: 15 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-05-19*
*Last updated: 2026-05-19 — Phase 16 reframing during /gsd-discuss-phase: question-intent baseline already ships as Phase 15's expected-symptom.yaml; BASELINE-02/03 removed; DOC-01 folded into BASELINE-04*
