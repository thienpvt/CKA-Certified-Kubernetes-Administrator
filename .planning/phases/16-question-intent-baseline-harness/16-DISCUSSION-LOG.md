# Phase 16: Question-Intent Baseline Harness - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-19
**Phase:** 16-question-intent-baseline-harness
**Areas discussed:** Pre-discussion reframing, Audit-tool shape, Authoring-discipline audit method, Diff output design, REQUIREMENTS rewrite

---

## Pre-Discussion Reframing

After the codebase scout, surfaced a structural conflict: the originally-scoped "intent.yaml" artifact already ships as Phase 15's `expected-symptom.yaml`, with the correct prose-derived polarity documented at `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md:84-87`. All 34 domain questions had a committed YAML.

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing expected-symptom.yaml | Phase 16 ships audit-tool + AUTHORING.md only; no new YAML schema | ✓ |
| Build separate intent.yaml as planned | Two YAMLs per question with overlapping content | |
| Show me more first | Defer decision until reading more of the existing artifact | |

**User's choice:** Reuse existing.
**Notes:** Decision implicitly removed BASELINE-02 (per-question authoring) and BASELINE-03 (per-mock baselines) from the milestone scope. Mock packs are reference-only `(pack, slug)` lists at `exams/blueprint-{alpha,bravo}/manifest.yaml` — no per-mock prose to baseline.

---

## Audit-tool shape

### Entry point

| Option | Description | Selected |
|--------|-------------|----------|
| New `cka-sim audit` subcommand | Discoverable; mirrors drill/exam pattern; lib/cmd/audit.sh | ✓ |
| Standalone scripts/audit-question.sh | Mirrors lint-question-symptom.sh; less discoverable | |
| Extend lint-question-symptom.sh with --audit flag | One file, two modes | |

### Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Single + pack + all | Three scopes mirroring drill semantics | ✓ |
| Single-question only | Forensic phase loops in shell wrapper | |
| All-only | Audit only runs on the whole corpus | |

### Output

| Option | Description | Selected |
|--------|-------------|----------|
| Stdout always; --report flag for markdown | Caller picks artifact destination | ✓ |
| Always-on markdown artifact | Auto-archives to .planning/forensics/audit-runs/ | |
| Stdout-only | Pipe to file in shell | |

**User's choice:** Subcommand + three scopes + stdout-default with --report flag.
**Notes:** Matches existing CLI conventions exactly. No surprises for downstream Phase 18 consumers.

---

## Authoring-discipline audit method

| Option | Description | Selected |
|--------|-------------|----------|
| Manual review per-question during forensic phase | Phase 18 reviewer reads question.md + YAML side-by-side | ✓ |
| Automated keyword-parity heuristic | Parser flags candidates for review | |
| Hybrid (heuristic + manual) | Belt-and-suspenders | |
| Skip in Phase 16; Phase 18 handles it implicitly | Trust audit-tool to surface real divergences | |

**User's choice:** Manual review per-question during forensic phase.
**Notes:** Phase 16 ships only the audit tool. Phase 18 wields it AND a manual prose-fidelity verdict (faithful / drifted / ambiguous) per question. This drove Decision D-05 — the audit tool embeds question.md prose excerpts in its output to make the manual review self-contained.

---

## Diff output design

### Diff layout

| Option | Description | Selected |
|--------|-------------|----------|
| Flat table per question | One row per resource × expect key | ✓ |
| Side-by-side YAML blocks | Claimed vs actual YAML, plus delta | |
| Summary table + expand-on-fail detail | Compact for whole-corpus runs | |

### Question.md prose reference

| Option | Description | Selected |
|--------|-------------|----------|
| Embed question.md excerpts in diff | Triage self-contained | ✓ |
| Cite file paths only | Reviewer opens question.md alongside | |
| No reference at all | Pure YAML-vs-cluster diff | |

### Empty-diff (PASS) behavior

| Option | Description | Selected |
|--------|-------------|----------|
| One-line PASS per clean question | Aggregate summary at end | ✓ |
| Silent on PASS | Maximum signal-to-noise | |
| Always print full table | Predictable shape regardless of outcome | |

**User's choice:** Flat table + embedded prose excerpts + one-line PASS + aggregate summary.
**Notes:** Output design supports Phase 18's two reviewer tasks (cluster-vs-YAML divergence AND prose-vs-YAML fidelity) in a single artifact. PASS suppression keeps stdout signal-dense for a 34-question run.

---

## REQUIREMENTS rewrite

| Option | Description | Selected |
|--------|-------------|----------|
| Update REQUIREMENTS.md to match reality | Drop BASELINE-02, BASELINE-03; fold DOC-01 into BASELINE-04 | ✓ |
| Keep REQ but re-classify in CONTEXT.md | Note BASELINE-02 already-shipped, BASELINE-03 N/A | |

**User's choice:** Rewrite the source of truth.
**Notes:** Net change: 18 → 15 active requirements. Phase 16 commitment shrinks from "5 requirements" to "BASELINE-01 + BASELINE-04". Roadmap structure unchanged (Phase 16 still ships these two).

---

## Claude's Discretion

- Markdown report format inside `--report path/to.md` — anything that renders cleanly on GitHub.
- Internal helper-function names in `lib/cmd/audit.sh`.
- Whether to extract the jsonpath translator + resource-kind allow-list to a shared `lib/symptom-diff.sh` (DRY) or keep them duplicated between `audit.sh` and `lint-question-symptom.sh`. Planner-level call after seeing the existing code shape.
- Exit code semantics (recommended: 0 = all PASS, 1 = at least one FAIL, 2 = preflight error).

## Deferred Ideas

- Wire `cka-sim audit` into GHA `validate.yml` — v1.0.3+ if continuous prose-fidelity checking proves needed.
- Automated keyword-parity heuristic for prose-fidelity — v1.0.3+ follow-up if Phase 18's manual review surfaces enough drift to justify automation.
- Refresh `.planning/codebase/ARCHITECTURE.md` and `STRUCTURE.md` — they describe the pre-v1.0 study guide, not cka-sim. Out of v1.0.2 scope.
- PROJECT.md 38→34 question-count fix — bundled into Phase 16's AUTHORING.md commit as a single-line correction.
