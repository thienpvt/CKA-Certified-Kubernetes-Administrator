# Phase 16: Question-Intent Baseline Harness - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship two things:

1. A new `cka-sim audit` subcommand (`lib/cmd/audit.sh`, mirrors `lib/cmd/drill.sh`) that runs each question's `setup.sh` against a clean kind+Calico cluster, captures actual post-setup state, diffs against the existing `expected-symptom.yaml` (Phase 15 artifact), and emits a human-readable flat-table diff for forensic triage. Stdout is the default surface; `--report path/to.md` persists the same content as a markdown artifact.
2. A new `docs/AUTHORING.md` workflow guide that walks a question author through the test-artifact triplet (`expected-symptom.yaml` / `lib/baseline.sh` snapshot / `lib/grade.sh`) with a worked example deriving `expected-symptom.yaml` from `question.md` prose. Cross-links the existing schema doc (`cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md`) and the candidate-state baseline doc (`cka-sim/lib/GRADING-HONESTY.md`).

Phase 16 is greenfield infrastructure. It does NOT author any new YAML, does NOT regenerate existing `expected-symptom.yaml` files, does NOT wire into GHA `validate.yml`, and does NOT pass judgment on whether the 34 existing YAMLs are prose-faithful — that authoring-discipline audit lives in Phase 18, where the tool gets used.

</domain>

<decisions>
## Implementation Decisions

### Audit-tool shape

- **D-01:** Audit tool ships as a new `cka-sim audit` subcommand. Implementation in `cka-sim/lib/cmd/audit.sh`, sourced from `cka-sim` dispatcher the same way `drill.sh` / `exam.sh` are. Discoverable via `cka-sim list`/`help`. Mirrors the established subcommand convention; rejected the standalone-script and lint-flag variants for discoverability and consistency.
- **D-02:** Three scopes accepted (mirrors `drill` semantics):
  - `cka-sim audit <pack>/<question>` — single question
  - `cka-sim audit <pack>` — whole pack
  - `cka-sim audit` — all 34 domain questions
  Each scope emits an aggregate summary at the end (`N/<total> PASS, M FAIL, K errors`).
- **D-03:** Output: stdout always carries the human-readable diff. `--report path/to.md` flag persists the SAME content as a markdown artifact (no schema divergence between stdout and report). No always-on artifact directory. Mirrors how `cka-sim exam` writes a markdown report on demand.

### Diff output design

- **D-04:** Per-question layout is a flat table with columns `question | resource | jsonpath | claimed | actual | verdict`. One row per resource × expect key. Verdict glyphs: `✓` (match), `✗` (mismatch), `MISSING` (resource absent), `?` (lookup error). Reviewer can scan by verdict column to triage.
- **D-05:** Each question's diff includes a `Claim source:` block that cites question.md prose excerpts producing each expect key. Excerpts are pulled via line-range references (e.g., `question.md:5-7`) so the reviewer doesn't need to open question.md. This supports Phase 18's prose-fidelity manual review without forcing the reviewer to context-switch.
- **D-06:** PASS for a clean question prints a single line: `✓ <pack>/<id>: PASS (N/N expectations met)`. The full table is suppressed on PASS to keep stdout signal-dense. Aggregate summary prints unconditionally at run end: `N/M PASS, K FAIL, L errors`.

### Authoring-discipline audit method

- **D-07:** Phase 16 does NOT include an automated discipline check. The "is this YAML prose-faithful?" verdict is a manual side-by-side review of `question.md` + `expected-symptom.yaml`, executed during Phase 18 against `cka-sim audit` output. FORENSIC-v102.md gets a `prose-fidelity: faithful | drifted | ambiguous` column. Heuristic auto-detection rejected as imperfect; hybrid rejected as over-engineering for 34 reviews.

### Scope reframing (locked during this discussion)

- **D-08:** REQUIREMENTS.md was rewritten to remove BASELINE-02 (per-question authoring) and BASELINE-03 (per-mock baselines). Reasoning:
  - BASELINE-02: All 34 domain questions already have a committed `expected-symptom.yaml` from Phase 15 (CI-01). Schema is documented at `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` with the correct prose-derived polarity. Re-authoring would be churn.
  - BASELINE-03: Blueprint manifests at `exams/blueprint-{alpha,bravo}/manifest.yaml` are `(pack, slug)` reference lists, not reframed prose. Mocks resolve to the source domain-pack `question.md` at runtime. There is no per-mock prose to baseline. AUDIT-02 instead verifies each `(pack, slug)` reference resolves to a passing domain-pack audit.
- **D-09:** PROJECT.md claims 38 domain questions; actual count is 34 (storage 6 + W&S 8 + S&N 6 + CA 8 + Troubleshooting 6 = 34). Fix bundled with this phase as a side-effect of the AUTHORING.md update — no separate requirement.

### AUTHORING.md scope

- **D-10:** AUTHORING.md is a workflow guide focused on "how do I author a new question end-to-end?" — it cross-links the existing schema reference (`cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md`) rather than duplicating schema content. Sections: (a) the test-artifact triplet, (b) author workflow per artifact, (c) worked example deriving `expected-symptom.yaml` from `question.md` prose for one of the existing 34 questions, (d) `cka-sim audit` invocation reference. Discoverable from `cka-sim/README.md`.

### Claude's Discretion

- Markdown report file format inside `--report path/to.md` (header structure, table syntax, summary block placement) — anything that renders cleanly on GitHub is fine.
- Internal helper-function names within `lib/cmd/audit.sh` (planner picks).
- Whether to share helpers with `lint-question-symptom.sh` via a small extracted lib (e.g., `lib/symptom-diff.sh`) or keep separate. Both lint and audit need the same jsonpath translator and resource-kind allow-list — DRY is a planner-level call after seeing the existing code shape.
- Exit code semantics: stdout-only humans don't care, but a CI hook or test runner might. Recommendation: 0 = all PASS, 1 = at least one FAIL, 2 = error/preflight failure. Planner can refine.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing test-artifact triplet (the schema we're audit-ing against)
- `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` — Schema for `expected-symptom.yaml`. Documents prose-derivation polarity at lines 84–87 (the lock for D-07's manual review). Allowed kinds at lines 36–48. Substitution rules (`${CKA_SIM_LAB_NS}`) at 50–55. Open-world semantics at 56–66.
- `cka-sim/scripts/lint-question-symptom.sh` — Reference implementation of the diff core. Contains the jsonpath translator (`_jsonpath_to_jq`), the resource-kind allow-list (`KIND_ALIAS`), the cluster-scoped-kind helper (`_is_cluster_scoped`), and per-question lab-namespace generation (`cka-sim-lint-<pack>-<slug>`). Audit subcommand should reuse this logic — extract to a shared lib if useful.
- `cka-sim/lib/baseline.sh` — Phase 07.1 candidate-state baseline (snapshots cluster *before* candidate work, used by graders). Audit must NOT touch this; AUTHORING.md must explain how it differs from `expected-symptom.yaml`.
- `cka-sim/lib/GRADING-HONESTY.md` — Phase 07.1 doc on the candidate-state baseline. AUTHORING.md cross-links it as the third leg of the triplet.

### Existing CLI subcommand patterns (mirror these for audit.sh)
- `cka-sim/lib/cmd/drill.sh` — Single-question runner. Mirror its preflight/cleanup/EXIT-trap pattern. Lines 309-318 are the canonical baseline-wiring block (referenced by `uat-phase{10,11,13}.sh`).
- `cka-sim/lib/cmd/exam.sh` — Multi-question runner with markdown report writing (`exam-report.sh`). Mirror its `--report` flag pattern if any.
- `cka-sim/bin/cka-sim` (or equivalent dispatcher) — Where the new `audit` subcommand registers. Inspect to learn the registration convention.
- `cka-sim/lib/cmd/help.sh`, `cka-sim/lib/cmd/list.sh` — Update these to surface the new subcommand.

### Sample question.md / expected-symptom.yaml pair (worked-example source)
- `cka-sim/packs/storage/01-pvc-binding/question.md` — Reference question for the AUTHORING.md worked example. Already cited in EXPECTED-SYMPTOM-SCHEMA.md §"Worked example".
- `cka-sim/packs/storage/01-pvc-binding/expected-symptom.yaml` — The corresponding YAML. Decision D-05's `Claim source:` block extracts excerpts from this question.md.

### v1.0.2 milestone-level
- `.planning/PROJECT.md` — Milestone goal + verification model. Question count needs the 38→34 correction (D-09).
- `.planning/REQUIREMENTS.md` — v1.0.2 scope. Phase 16 covers BASELINE-01 + BASELINE-04. BASELINE-02/03 removed during this discussion.
- `.planning/ROADMAP.md` — Phase 16 success criteria. Phase 18 (forensic re-audit) is the primary downstream consumer of `cka-sim audit`.
- `.planning/STATE.md` — Current position pointer; v1.0.2 backlog reference.
- `.planning/milestones/v1.0.1-ROADMAP.md` — Phase 15 reference: how `expected-symptom.yaml` and `lint-question-symptom.sh` originally landed.

### Codebase scout findings (architecture refresh deferred — maps are pre-cka-sim)
- `.planning/codebase/ARCHITECTURE.md`, `STRUCTURE.md` — Stale; describe the pre-v1.0 study-guide layout, NOT the cka-sim runtime. Do NOT use these maps; the live structure was scouted directly during this discussion. Updating them is out of Phase 16 scope.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`cka-sim/scripts/lint-question-symptom.sh`** — Source of the jsonpath translator, resource-kind allow-list, cluster-scoped detection, and per-question lab-namespace generator. The audit subcommand should reuse this logic; planner decides whether to extract to a shared `lib/symptom-diff.sh` (DRY) or copy (low risk of regressing the lint).
- **`cka-sim/lib/cmd/drill.sh:309-318`** — Canonical setup→baseline-prep→grade orchestration block. The audit subcommand reuses the setup→capture step but skips baseline+grade (audit doesn't run candidate work).
- **`cka-sim/lib/exam-report.sh`** — Markdown report writer for `cka-sim exam`. If `--report` flag for audit needs structured markdown, the planner can either reuse this or write a smaller dedicated writer in `lib/cmd/audit.sh` — the table format from D-04 is simple enough that a fresh implementation is reasonable.
- **`cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md`** — Already documents the schema; AUTHORING.md cross-links it instead of duplicating.

### Established Patterns

- **One subcommand per `lib/cmd/*.sh` file**, sourced from a central dispatcher. New `audit.sh` slots in alongside `drill.sh`, `exam.sh`, `score.sh`, `list.sh`, `bootstrap.sh`, `doctor.sh`.
- **Preflight gate at top of every subcommand**: `kubectl cluster-info` check (warn-skip if no cluster) + tool checks (`jq`, `python3`, `python3 -c 'import yaml'`). `lint-question-symptom.sh` lines 26–35 are the pattern.
- **Per-question lab namespace** generated as `cka-sim-<context>-<pack>-<slug>` (the lint uses `cka-sim-lint-<pack>-<slug>`). Audit should follow the same shape — e.g., `cka-sim-audit-<pack>-<slug>` — to avoid colliding with lint runs.
- **Setup-output capture via kubectl get -o json + jq** (no `yq` dependency), matching the rest of cka-sim's pure-bash + jq + python3-yaml stack.
- **Atomic mktemp + mv for any persisted artifact** (drill.sh report-file pattern). `--report path/to.md` writer should follow this.
- **EXIT trap for cleanup** of per-run lab namespaces. Critical when running `cka-sim audit` over all 34 questions; namespaces leak otherwise.

### Integration Points

- **`cka-sim/bin/cka-sim` dispatcher** — Register `audit` alongside other subcommands.
- **`cka-sim/lib/cmd/help.sh`, `lib/cmd/list.sh`** — Surface `audit` in help output and `cka-sim list` if applicable.
- **`cka-sim/lib/colors.sh`, `cka-sim/lib/log.sh`** — Reuse for header/info/warn/die output. `lint-question-symptom.sh` uses the same.
- **`cka-sim/README.md`** — Add `cka-sim audit` to the subcommand summary; link AUTHORING.md from the docs section.
- **`cka-sim/AUTHORING.md`** (new file) — This phase's documentation deliverable. Cross-link from cka-sim/README.md and from the schema doc.

</code_context>

<specifics>
## Specific Ideas

- The user reframed the original "intent.yaml" artifact during discussion after a side-by-side read of `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` revealed the artifact already exists with the correct polarity. Phase 16's deliverable shrank from "build a third YAML schema" to "build the audit-mode tool that reads the existing schema."
- The motivating bug pattern from the user (alpha-q1 "consumer pod in pending state" but pod is actually Running) is exactly what the existing `expected-symptom.yaml` + `lint-question-symptom.sh` is designed to catch. If those failed to catch it before, the cause is either (a) the YAML was generated from setup output instead of question.md prose (Phase 18 manual review will surface this), or (b) the YAML never shipped for that question (already disproven — coverage is 100%).

</specifics>

<deferred>
## Deferred Ideas

- **Wire `cka-sim audit` into GHA `validate.yml`** — Decided audit is one-shot during forensic phases. Future drift detection stays with `lint-question-symptom.sh`. If we later want continuous prose-fidelity checking, that's a v1.0.3+ requirement.
- **Automated keyword-parity heuristic for prose-fidelity** — Rejected as Phase 16 work; could land as a v1.0.3 follow-up if the manual Phase 18 review surfaces enough drift to justify automation.
- **Refresh `.planning/codebase/ARCHITECTURE.md` and `STRUCTURE.md`** to reflect the cka-sim runtime — Out of scope for v1.0.2; create a separate doc-refresh phase or fold into v1.0.2 close-out if time permits.
- **PROJECT.md 38→34 question-count fix** — Bundled into Phase 16 AUTHORING.md commit as a single-line correction; not a standalone requirement.

</deferred>

---

*Phase: 16-Question-Intent Baseline Harness*
*Context gathered: 2026-05-19*
