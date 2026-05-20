# Phase 18: Forensic Re-Audit (Blind) - Context

**Gathered:** 2026-05-20
**Status:** Ready for planning
**Mode:** Auto-generated (--auto) — pre-traced from Phase 16 reframe + Phase 17 closure + user decision 2026-05-19

<domain>
## Phase Boundary

Run `cka-sim audit` against all 34 expected-symptom.yaml-bearing questions on a clean kind+Calico cluster. Capture intent-vs-actual diffs into `.planning/forensics/FORENSIC-v102.md`, classifying each finding by severity (HIGH/MED/LOW) and root-cause class (`setup-drift` / `question-prose-wrong` / `framing-mismatch` / `grader-disagrees`). The ledger drives concrete decimal sub-phases inserted under Phases 19 (HIGH) and 20 (MED).

This phase does NOT fix any bugs — it surfaces them. Remediation lands in 19.x and 20.x sub-phases.
</domain>

<scope_reframe>
## Scope Reframe (vs ROADMAP.md)

ROADMAP.md Phase 18 references "38 domain-pack questions + 34 mock framings = 72 audits". Reality after Phase 16 reframing:

- Total questions ship-ready: **34** across 5 domain packs (cluster-architecture/8 + services-networking/6 + storage/6 + troubleshooting/6 + workloads-scheduling/8). All 34 carry an `expected-symptom.yaml`.
- Phase 16 explicitly DID NOT introduce a separate `intent.yaml` artifact — it reframed the audit-only contract to use the existing `expected-symptom.yaml` corpus as the intent source. The third audit-only artifact never landed; ROADMAP.md text is stale.
- Mock blueprint packs (`blueprint-alpha`, `blueprint-bravo`) live as `cka-sim/blueprints/` per Phase 7/8 narrative — but the actual implementation composes mocks from domain-pack questions by reference (no separate per-framing intent files). There are no separate `intent.yaml` files for mock framings. Test fixture at `cka-sim/tests/fixtures/exam/packs/mock-pack-alpha` is exam-mode test data, not a real pack.

**Locked decision:** Phase 18 audits the 34 domain-pack `expected-symptom.yaml` files. Mock-framing audit is dropped from this phase's scope (no per-framing intent files to audit against). If framing-drift bugs exist, they surface naturally during Phase 21's milestone close-out drill UATs.

**3 unsupported-on-kind questions are skipped per Phase 17 BLG-02:** cluster-architecture/02-etcd-backup-restore, storage/04-csi-volumesnapshot, workloads-scheduling/06-static-pod. Effective audit set: **31 questions** on kind+Calico.
</scope_reframe>

<decisions>
## Implementation Decisions

### Cluster path
- **D-01:** Run `cka-sim audit` against a local kind+Calico cluster matching the GHA validate.yml recipe (kind v0.23.0+ — local install via chocolatey is v0.31.0, compatible; Calico v3.27.3; `disableDefaultCNI: true`, `podSubnet: 192.168.0.0/16`, 1 control-plane + 1 worker). Decision per user 2026-05-19: "Run kind+Calico locally via Docker".
- **D-02:** The cluster is single-purpose (this phase only). Tear down after FORENSIC-v102.md ships. No cluster-survival between Phases 18 → 19 → 20 — sub-phases stand up their own clusters or run unit-test fixtures only.

### Audit invocation
- **D-03:** Invoke as `bash cka-sim/bin/cka-sim audit --report .planning/forensics/FORENSIC-v102-raw.md` once across all 34 packs. The 3 BLG-02 questions emit the structural skip line and don't count toward PASS/FAIL/error.
- **D-04:** Audit's `--report` markdown output is the raw input. The forensic ledger is hand-shaped from this output — Claude reads the raw report, classifies each FAIL by severity + root-cause class, and produces FORENSIC-v102.md in the v1.0.1 forensics-report shape (table format: `question-id × bug-class × severity × suggested-fix`).
- **D-05:** Two-pass approach: (1) raw audit run captures every FAIL/MISSING/ERROR; (2) hand classification round assigns severity and root-cause class. The raw report file is committed alongside the ledger as primary evidence.

### Severity classification rubric
- **D-06:** **HIGH** — symptom claim is structurally wrong (claims a state setup.sh cannot produce; OR claim contradicts question.md prose; OR causes ref-solution to score < max/max). Pattern: same shape as v1.0.1 BUG-H01..H06.
- **D-07:** **MED** — symptom claim is correct in spirit but encoding-fragile (jsonpath returns `<missing>` for unset fields; framing-mismatch where mock and domain-pack disagree on the same setup; library-level helper bugs). Pattern: same shape as v1.0.1 BUG-M01..M09.
- **D-08:** **LOW** — cosmetic / over-prescriptive (claim could be loosened without losing trap-detection signal). Captured but no remediation phase generated; deferred to v1.0.3+ if relevant.

### Root-cause class rubric
- **D-09:** `setup-drift` — `setup.sh` no longer produces what `expected-symptom.yaml` claims (or what `question.md` prose says). Fix lands in setup.sh.
- **D-10:** `question-prose-wrong` — `question.md` describes behaviour that doesn't match the actual setup. Fix lands in question.md.
- **D-11:** `framing-mismatch` — mock-pack reframing disagrees with the underlying domain-pack question's setup output. (DEFERRED: out-of-scope per scope_reframe — no mock intent files to compare.)
- **D-12:** `grader-disagrees` — `grade.sh` scores the question differently than the symptom-diff implies. Fix lands in grade.sh assertion list.

### Tech-debt folded from Phase 17
- **D-13:** Two pre-existing unit-test reds routed from Phase 17 verification gaps_found:
  1. `cluster-architecture__05-audit-policy` — empty submission expects `SCORE: 0/1`, gets `SCORE: 0/4`. Same fixture-vs-grader-drift class as Phase 17's BLG-05; root-cause class is `grader-disagrees` once classified. Treated as a pre-baked HIGH candidate; the audit will likely re-surface it as setup vs grade.sh divergence.
  2. `report_golden` — exam report rendering text differs from `tests/fixtures/exam/expected-report.md`. Not symptom-diff-detectable (it's exam-mode rendering, not per-question state). Captured as a separate ledger entry under a new bug-class `report-rendering-drift` outside the standard 4 classes.
- **D-14:** BLG-06 shellcheck/yamllint findings (Phase 17 follow-up scaffolding) are tracked in the ledger as a separate `lint-debt` block but are NOT classified by the per-question rubric. Phase 19/20 sub-phases may pull them in at the operator's discretion.

### Sub-phase generation
- **D-15:** After FORENSIC-v102.md ships, generate decimal sub-phase plans via `/gsd-phase --insert`:
  - Phase 19.x for each HIGH finding (one per bug; mirrors v1.0.1 P10/P11 plan-per-bug shape).
  - Phase 20.x for each MED finding grouped by root-cause class (mirrors v1.0.1 P13/P14 grouping).
- **D-16:** Each sub-phase declares its own `BUG-H##` or `BUG-M##` requirement keyed off the FORENSIC-v102.md row id. No bug-IDs are pre-baked in this CONTEXT.md.

### Plan boundaries
- **D-17:** Phase 18 ships as 2 sequential plans:
  - **18-01:** Stand up local kind+Calico cluster, run `cka-sim audit --report` against all 34 packs, capture raw output. Tear down cluster.
  - **18-02:** Hand-classify the raw report into FORENSIC-v102.md ledger (per-question rubric application + tech-debt folding); insert decimal sub-phases via `/gsd-phase --insert` for Phase 19.x and 20.x.
- **D-18:** Plan 18-02's `/gsd-phase --insert` calls produce ROADMAP.md edits but not yet plan-phase artifacts. Phase 19 and 20 entries thereafter pick up via gsd-autonomous's normal discover_phases loop on subsequent iterations.

### Claude's discretion
- Severity calls on borderline findings (HIGH-ish vs MED-ish): apply the rubric strictly; when in doubt, default to MED.
- Whether to commit the raw audit output alongside the ledger or treat the ledger as authoritative — D-05 says ship both. Operator can prune the raw file later.
- Local kind cluster name: `cka-sim` (matches the GHA recipe).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 17 / 16 / 15 carryover artifacts
- `cka-sim/lib/cmd/audit.sh` — Phase 16 audit subcommand (chmod fixed Phase 17). The driver Phase 18 invokes.
- `cka-sim/lib/symptom-diff.sh` — Phase 16+17 shared diff core (sub(name) wraps + is_unsupported_on_kind helper + kubectl-wait pre-step). Audit + lint both source it.
- `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` — schema reference; classification rubric leans on the open-world contract.
- `cka-sim/packs/*/*/expected-symptom.yaml` — 34 audit targets.

### v1.0.1 forensic ledger (shape reference)
- `.planning/forensics/report-20260517-091657-full-audit.md` — v1.0.1's full audit. FORENSIC-v102.md mirrors its column layout (`question-id × bug-class × severity × suggested-fix`).

### Phase 17 verification (tech-debt input)
- `.planning/phases/17-v1-0-2-backlog-cleanup/17-VERIFICATION.md` — gaps_found section names the 2 platform reds routed here.

### CI recipe (cluster setup reference)
- `.github/workflows/validate.yml` — symptom-diff job's kind+Calico setup steps are the local-cluster recipe (lines 103-148).

### Phase 18 outputs (to be created)
- `.planning/forensics/FORENSIC-v102.md` — the canonical ledger.
- `.planning/forensics/FORENSIC-v102-raw.md` — raw audit output (`cka-sim audit --report`).

### Milestone-level
- `.planning/STATE.md` — v1.0.2 progress.
- `.planning/REQUIREMENTS.md` — AUDIT-01..04 definitions.
- `.planning/ROADMAP.md` — Phase 18 (success criteria 1+3 in scope; 2 dropped per scope_reframe; 4 lands in 18-02).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`cka-sim/lib/cmd/audit.sh`** — already produces `--report` markdown with PASS one-liner / FAIL table / Claim source excerpt / aggregate summary. Phase 18 just runs it.
- **`cka-sim/lib/symptom-diff.sh`** — `is_unsupported_on_kind` helper (Phase 17) skips the 3 BLG-02 questions cleanly with a structural skip line in the report.
- **`.github/workflows/validate.yml` symptom-diff job** — kind+Calico setup steps are copy-pasteable for local cluster bootstrap.

### Established Patterns
- **v1.0.1 forensic-report shape** — `report-20260517-091657-full-audit.md` is the layout template. FORENSIC-v102.md mirrors it.
- **Plan-per-bug for HIGH** (v1.0.1 P10/P11), **grouped-by-root-cause for MED** (v1.0.1 P13/P14). Phase 19.x and 20.x follow this.
</code_context>

<specifics>
## Specific Ideas

- The audit may surface a `cluster-architecture/05-audit-policy` finding consistent with the unit-test red. If so, that's one HIGH ledger entry sourced from both Phase 17 tech-debt AND the live audit — converge on a single bug ID.
- `storage/01-pvc-binding`'s post-Plan-17-03 YAML (Bound/Bound) is the new baseline; expect the audit to PASS it cleanly.
- `cluster-architecture/08-priorityclass`'s Plan 17-03 rewrite (presence-only) likewise should PASS cleanly.
- The 3 BLG-02 skips emit a `ⓘ SKIPPED` line in the audit report — don't classify those as bugs.
- Calico-on-kind convergence: BLG-04's wait pre-step (Plan 17-03) handles the 3 known affected Deployments. Other Deployment-Available claims surface during this audit; the wait pre-step is generic across all of them.
</specifics>

<deferred>
## Deferred Ideas

- **Mock-pack framing-drift audit** — out of scope per scope_reframe (no per-framing intent files exist). Surface naturally during Phase 21's drill UAT batch if any reframings disagree with their underlying domain-pack questions.
- **`report_golden` exam-mode rendering fix** — captured in ledger under `report-rendering-drift` class but remediation deferred until a post-Phase-20 follow-up. Doesn't fit the per-question forensic rubric.
- **BLG-06 per-finding shellcheck/yamllint triage** — handled in Plan 17-05's documented follow-up flow; tracked in ledger as `lint-debt` but not classified by question rubric.
</deferred>

---

*Phase: 18-forensic-re-audit-blind*
*Context gathered: 2026-05-20 (auto, pre-traced from P16 reframe + P17 closure)*
