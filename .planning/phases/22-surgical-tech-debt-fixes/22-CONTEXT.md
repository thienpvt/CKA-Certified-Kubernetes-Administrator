# Phase 22: Surgical Tech-Debt Fixes - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Three independent, single-point bug fixes land — drill-mode renders namespace-substituted prompts, workloads-scheduling/06-static-pod setup either succeeds on the lab cluster or is documented as unsupported, and the symptom-diff regression test fails as designed when its expected-symptom.yaml is mutated.

This is a pure tech-debt phase. Every requirement is pre-traced from v1.0.2 close-out evidence (`.planning/forensics/FORENSIC-v102.md` + `cka-sim/current-tests/step{1,2,4,5}-results.txt`). No new features. No question authoring. No mock-pack changes.

**Out of scope for this phase:** anything in BLG-06 / BLG-07 (those land in Phase 23). New questions, new packs, new graders. Architectural changes to drill/exam runners beyond the single namespace-render line.
</domain>

<decisions>
## Implementation Decisions

### DRILL-NS-01 — drill-mode envsubst render

- Mirror exam-mode pattern at `cka-sim/lib/cmd/exam.sh:196` exactly: pure-bash `${question_content//\$\{CKA_SIM_LAB_NS\}/$CKA_SIM_LAB_NS}` substitution. No `envsubst` dependency.
- Single-point change in `cka-sim/lib/cmd/drill.sh` around line 321 (currently `cat "$CKA_SIM_QUESTION_DIR/question.md"`). Replace with the read-into-variable + parameter-expansion pattern that exam.sh already uses.
- Substitute ONLY `${CKA_SIM_LAB_NS}` — don't expand other `${VAR}` shapes in question.md (no shell expansion, no envsubst). Question authors may have other dollar-sign content.
- 20+ `question.md` files keep their `${CKA_SIM_LAB_NS}` literals — fix is in the renderer, NOT the prose. Do NOT sweep question.md files.
- Smoke test: invoke drill mode against 2-3 questions across packs (storage/01, services-networking/01, troubleshooting/05) and visually verify the resolved namespace appears in the rendered prompt. No literal `${CKA_SIM_LAB_NS}` should appear in candidate-visible output.
- Add a unit-test case in `cka-sim/tests/cases/` (mirror `drill_namespace_construction.sh` shape) that asserts the rendered output contains the resolved namespace and not the literal placeholder.

### AUDIT-W&S06 — workloads-scheduling/06-static-pod lab-cluster setup drift

- Investigation-first: read `cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh` to identify what failed on the lab cluster. Likely candidates: SSH topology assumption (worker-node access), `/etc/kubernetes/manifests/` permissions, `kubectl debug node`-style helpers that don't work in the audit harness sandbox, or a `read_node_worker` helper returning empty.
- Audit harness writes namespace `cka-sim-audit-workloads-scheduling-06-static-pod` (per `cka-sim/lib/symptom-diff.sh:82` `compute_ns`). Setup.sh failed against this namespace on the lab cluster — see `cka-sim/current-tests/step2-results.txt:41-44`.
- Two acceptable outcomes per ROADMAP P22 success criterion 2:
  - **Preferred:** fix `setup.sh` to succeed on a 1-control-plane + 2-workers kubeadm cluster. Audit advances 33/34 → 34/34.
  - **Acceptable:** declare the question unsupported in audit mode using the same `unsupported-on-kind`-style exclusion shape Phase 17 added (`cka-sim/lib/symptom-diff.sh:75-78` `is_unsupported_on_kind`). Add an `unsupported-in-audit-mode: true` (or similar) flag to metadata.yaml; honor it in `cka_sim::symptom_diff::run_one` to emit a deterministic SKIP. Audit advances 33/34 + 1 ERROR → 33/34 + 1 SKIP.
- Decision deferred to plan-phase / execute-phase based on what investigation finds. NEITHER outcome is "best" in absolute — preference depends on whether the failure is a real bug in setup.sh (fix) or an environmental constraint the audit harness can't simulate (skip).
- Drill-mode and exam-mode behavior MUST be preserved — the question still works for candidates running it directly, even if audit harness skips it. Verify this: `bash bin/cka-sim drill workloads-scheduling 6` on the lab cluster scores max/max under ref-solution.

### LINT-01 — symptom-diff regression test masked by Bad file descriptor

- Root cause identified during discuss: `cka-sim/lib/symptom-diff.sh:91-96` `_emit_row` writes to fd 3 with `>&3 2>/dev/null || true`. When called from lint mode (which does NOT open fd 3), the `>&3` redirect itself fails before the printf executes — bash emits `Bad file descriptor` to stderr; the `|| true` swallows the exit code; the row is never written; the audit-mode-only side channel falls silent.
- The deeper bug is that **lint mode relies on `_emit_row ERROR` calls to mark divergence**, but those ERROR rows go to fd 3 only — lint mode reads stderr (`err "..."` calls) for human-readable failure citations, not the row stream. So when only `_emit_row ERROR` fires (no `err` call), lint can't see the divergence.
- Fix shape: `_emit_row` must be safe to call when fd 3 is not open (current behavior: noisy stderr leak, swallowed by `2>/dev/null`). The current `2>/dev/null` is on the wrong side of the redirect — it suppresses printf errors, not the bash redirect-failure error. Move the redirect-error suppression to apply to the redirect itself: wrap the whole call in `{ ... ; } 2>/dev/null` OR check fd 3 with `[[ -e /dev/fd/3 ]]` before emitting OR use an `exec 3>/dev/null` initializer in lint mode to always have fd 3 open.
- Verify the regression test catches the deliberate mutation: `bash cka-sim/tests/cases/symptom-diff-regression.sh` returns non-zero with `expected 'Bound', got 'Pending'` in stderr. This is the explicit ROADMAP P22 success criterion 3.
- Phase 15's quality gate is restored to actually catching drift — this means subsequent milestones can trust `lint-question-symptom.sh` not to silently pass on broken expected-symptom.yaml files.

### Claude's Discretion

- File ordering of fixes during execute (DRILL-NS-01 / AUDIT-W&S06 / LINT-01 are independent and can land in any order).
- Specific commit shape (one commit per REQ vs one commit per file) — let plan-phase decide based on touched-file overlap.
- Whether to add a regression test for DRILL-NS-01 or rely on the smoke-test only — plan-phase weighs the cost.
- Whether to lift the `2>/dev/null` workaround on `_emit_row` callers once the underlying redirect is safe.
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Exam-mode envsubst pattern** — `cka-sim/lib/cmd/exam.sh:191-196`. Pure-bash parameter expansion, single-token substitution. Already shipped via quick task `260517-hvo`.
- **`cka_sim::symptom_diff::is_unsupported_on_kind`** — `cka-sim/lib/symptom-diff.sh:75-78`. Phase 17 added the kind-skip flag pattern; AUDIT-W&S06 can copy this shape if it lands as skip rather than fix.
- **`cka_sim::symptom_diff::compute_ns`** — `cka-sim/lib/symptom-diff.sh:82-89`. RFC 1123 ns builder. Read-only — already does the right thing.
- **Test-case shape** — `cka-sim/tests/cases/drill_*.sh`, `cka-sim/tests/cases/symptom-diff-*.sh`. Existing test scaffold for new unit cases.

### Established Patterns

- **Question.md authoring** — `${CKA_SIM_LAB_NS}` is the convention (20+ files use it). Renderer-level substitution preserves this.
- **Audit-harness exclusion** — `metadata.yaml: unsupported-on-kind: true` honored at `symptom-diff.sh:75-78`. AUDIT-W&S06 may add `unsupported-in-audit-mode` or similar.
- **Lint vs audit mode separation** — `_emit_row` uses fd 3 as audit-only side channel; `err` writes to stderr for both modes. LINT-01 fix preserves this separation but stops the silent failure.

### Integration Points

- **`cka-sim/lib/cmd/drill.sh:321`** — DRILL-NS-01 single-line change point.
- **`cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh`** — AUDIT-W&S06 investigation start (and possibly fix point).
- **`cka-sim/lib/symptom-diff.sh:91-96`** — LINT-01 single-function change point.
- **`cka-sim/scripts/test.sh`** — runs unit cases including `drill_*` (new DRILL-NS-01 case slots in here) and `symptom-diff-regression.sh`.

</code_context>

<specifics>
## Specific Ideas

- **DRILL-NS-01 fix MUST mirror exam-mode** — same parameter-expansion shape. Don't introduce a different mechanism (no envsubst, no awk, no sed pipeline). Pure-bash `${var//pattern/replacement}`.
- **AUDIT-W&S06 either-fix-or-skip is acceptable** — the success criterion is "deterministic outcome", not "fix at all costs". If the question genuinely cannot run in the audit harness's namespace-isolated mode (because static pods live on `/etc/kubernetes/manifests/` which is outside any namespace), declaring it audit-incompatible is the right call.
- **LINT-01 fix MUST verify the regression test catches mutation** — that's the explicit P22 success criterion. Don't just fix `_emit_row`; re-run `cka-sim/tests/cases/symptom-diff-regression.sh` after the fix and confirm exit non-zero.

</specifics>

<deferred>
## Deferred Ideas

- **Sweep question.md files to use `$CKA_SIM_LAB_NS` (no braces) or some other convention** — out of scope. Renderer fix is sufficient. If we ever want to reduce ambiguity, that's a v2.0 cleanup.
- **Refactor `_emit_row` to write a structured log file unconditionally** — out of scope. Lint vs audit mode separation is correct; only the silent-failure mode needs fixing.
- **Add a CI gate that runs `symptom-diff-regression.sh` on every push** — would be defensive but adds CI time; defer to v1.0.4 if needed.
- **Make audit-mode skip flag generic (`unsupported-in: kind|audit|...`)** — design improvement, not a P22 requirement. Plan-phase decides whether to ship narrow `unsupported-in-audit-mode: true` or broader `unsupported-environments: [kind, audit]`.

</deferred>

<canonical_refs>
## Canonical References

Downstream agents (researcher, planner, executor) MUST read these before acting:

- `.planning/ROADMAP.md` — Phase 22 goal + 4 success criteria (lines 181-191)
- `.planning/REQUIREMENTS.md` — DRILL-NS-01, AUDIT-W&S06, LINT-01 acceptance criteria
- `.planning/forensics/FORENSIC-v102.md` — v1.0.2 ledger; provides the "Bad file descriptor" symptom evidence
- `.planning/STATE.md` — v1.0.2 Close-Out section; provides the "audit error: workloads-scheduling/06-static-pod" lab-cluster evidence (Step 2)
- `cka-sim/current-tests/step1-results.txt` — symptom-diff regression failure evidence (`Bad file descriptor` on line 94)
- `cka-sim/current-tests/step2-results.txt` — workloads-scheduling/06-static-pod setup.sh failure evidence (line 41-44)
- `cka-sim/lib/cmd/exam.sh` — exam-mode envsubst pattern (lines 191-196) — DRILL-NS-01 mirrors this exactly
- `cka-sim/lib/cmd/drill.sh` — DRILL-NS-01 fix point (line 321)
- `cka-sim/lib/symptom-diff.sh` — LINT-01 fix point (lines 91-96 `_emit_row`); AUDIT-W&S06 reference for `is_unsupported_on_kind` pattern (lines 75-78) and `compute_ns` (82-89)
- `cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh` — AUDIT-W&S06 investigation start
- `cka-sim/tests/cases/symptom-diff-regression.sh` — LINT-01 verification (must exit non-zero with mutated YAML after fix)

</canonical_refs>
