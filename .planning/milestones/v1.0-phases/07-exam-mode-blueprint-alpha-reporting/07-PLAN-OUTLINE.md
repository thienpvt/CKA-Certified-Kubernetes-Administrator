---
phase: 07
slug: exam-mode-blueprint-alpha-reporting
mode: chunked-outline
plan_count: 6
created: 2026-05-13
---

# Phase 7 Plan Outline

> Chunked-mode outline. No PLAN.md files written yet. Each row below becomes a
> dedicated `07-NN-PLAN.md` written in subsequent chunked-mode invocations.
>
> Decomposition derived from RESEARCH §"Recommended execution order" (lines
> 567-573) and PATTERNS file classification table. Wave assignments respect
> file-ownership rules (no two same-wave plans share `files_modified`).

---

## Phase Goal (from ROADMAP)

`cka-sim exam blueprint-alpha` runs a 2-hour 17-question mock end-to-end against
the candidate's cluster with flag/skip/pause/resume, then renders a Markdown
score report with per-domain breakdown and trap frequencies. `cka-sim score
[<ts>]` re-displays the report; `cka-sim list history` lists prior sessions.

## Phase Requirement IDs

`RUN-03, RUN-04, RUN-05, RUN-06, MOCK-01, MOCK-03, REPORT-01, REPORT-02`

---

## Plans

| Plan ID | Objective | Wave | Depends On | Files Modified (primary) | Requirements | Tasks (est) | Autonomous |
|---------|-----------|------|------------|--------------------------|--------------|-------------|------------|
| 07-01 | **Foundation: exam-state + exam-blueprint helpers + Wave-0 fixtures.** Create `lib/exam-state.sh` (atomic JSON read/write, schema v1, jq-based) and `lib/exam-blueprint.sh` (pure-bash YAML walker mirroring `drill.sh::_parse_manifest`, `validate()`, `resolve_question()`). Author Wave-0 fixtures consumed by every subsequent plan: 17-question synthetic `tests/fixtures/exam/mock-pack-alpha/`, `blueprint-mock-alpha.yaml`, `traps-mock-catalog.yaml`. Tests: `state_atomic_write.sh`, `state_schema.sh`, `blueprint_load.sh`, `blueprint_validate.sh`. Extend `tests/run.sh` to walk `tests/exam/`. | 1 | — | `cka-sim/lib/exam-state.sh`, `cka-sim/lib/exam-blueprint.sh`, `cka-sim/tests/exam/{state_atomic_write,state_schema,blueprint_load,blueprint_validate}.sh`, `cka-sim/tests/fixtures/exam/mock-pack-alpha/**`, `cka-sim/tests/fixtures/exam/blueprint-mock-alpha.yaml`, `cka-sim/tests/fixtures/exam/traps-mock-catalog.yaml`, `cka-sim/tests/run.sh` | RUN-05, MOCK-01 (validate fn) | 3 | yes |
| 07-02 | **Report renderer: `lib/exam-report.sh`.** Implement `cka_sim::report::{render,header,domain_table,trap_table,next_drills,question_detail,compute_total}` using the heredoc pattern from `drill.sh::render_header` and the atomic-write idiom (`mktemp` -> heredocs concatenated -> `mv`). Per-domain table sorted percentage-asc (D-22, `LC_ALL=C sort`). Trap table = top-5 by raw count (D-24). Next drills = bottom-3 weak domains skipping any >=80% (D-25). Total = sum (q_score/q_max)*weight per domain normalized to /100, pass=66 (D-23). Author golden fixtures `session-fixture.json` + `expected-report.md`. Test: `report_golden.sh` (byte-equal diff). | 2 | 07-01 | `cka-sim/lib/exam-report.sh`, `cka-sim/tests/exam/report_golden.sh`, `cka-sim/tests/fixtures/exam/session-fixture.json`, `cka-sim/tests/fixtures/exam/expected-report.md` | REPORT-01 | 2 | yes |
| 07-03 | **Runtime: `lib/exam-timer.sh` + `lib/cmd/exam.sh` orchestrator.** Replace `lib/cmd/exam.sh` Phase 1 stub. Timer subshell per RESEARCH §"Timer subshell" (`tput sc/cup/el/rc`, fork via `&`, PID in `CKA_SIM_TIMER_PID`, parent EXIT trap kills it). Orchestrator owns `start_new`, `resume`, `question_loop`, `present_question`, `handle_action`, signal traps (`on_int` flags + persists, `on_tstp` saves + `kill -STOP $$`, `on_cont` shifts deadline by pause delta, `on_exit` runs reset.sh per set-up question + kills timer), `batch_grade` (idx order, skipped -> 0/max no grade.sh, others run grade.sh against still-set-up namespace per D-11), `confirm_submit` (D-15 specifics: flagged/skipped counts pre-submit). Tests: `timer_render.sh` (CKA_SIM_TIMER_FAST scale, monotonic decrement), `signal_handlers.sh` (INT+TSTP+EXIT cases per RUN-06), `exam_resume_after_int.sh` (SIGINT mid-Q, `--resume <ts>`, deadline arithmetic against frozen `CKA_SIM_NOW_OVERRIDE`), `exam_end_to_end.sh` (mock graders, 17 graded entries + final_report_path on disk). | 3 | 07-01 | `cka-sim/lib/exam-timer.sh`, `cka-sim/lib/cmd/exam.sh`, `cka-sim/tests/exam/{timer_render,signal_handlers,exam_resume_after_int,exam_end_to_end}.sh` | RUN-03, RUN-04, RUN-05, RUN-06 | 3 | yes |
| 07-04 | **Adjacent commands: `lib/cmd/score.sh` + `lib/cmd/list.sh` history subcommand.** Replace `score.sh` Phase 1 stub: with no `<ts>` lists most recent + prints; with `<ts>` arg prints that report; if `<ts>.md` missing but `<ts>.json` exists, regenerate via `cka_sim::report::render` then print (D-26). Extend `list.sh` Phase 1 stub with `case "${1:-}"` dispatch including `history` subcommand: walk `~/.cka-sim/sessions/*.json` via `cka_sim::state::list_sessions`, render 5-column table (Started, Blueprint, Score, Pass/Fail, Status) sorted started_at desc, mark in-progress sessions per D-27. Tests: `score_command.sh`, `list_history.sh`. | 4 | 07-02, 07-03 | `cka-sim/lib/cmd/score.sh`, `cka-sim/lib/cmd/list.sh`, `cka-sim/tests/exam/{score_command,list_history}.sh` | REPORT-02 | 2 | yes |
| 07-05 | **Blueprint content: `exams/blueprint-alpha/manifest.yaml` + README.** Author `manifest.yaml` per D-18 schema, with the 17-question draw from RESEARCH §"Final draw — sum 129 min" (sum 129 in [120,130], counts 2/3/3/4/5, no adjacent same-domain). Include weighting `10/15/20/25/30`, `durationMinutes: 120`, `estimatedMinutesBudget: [120, 130]`, `disclaimer: "Not real CKA exam content; independently authored. Targets v1.35 CKA blueprint."` Author `README.md`: blueprint description, MOCK-03 disclaimer (literal string), D-15 deviation note ([120,130] not [110,120]), `cka-sim exam blueprint-alpha` invocation example. | 4 | 07-01 | `exams/blueprint-alpha/manifest.yaml`, `exams/blueprint-alpha/README.md` | MOCK-01 (content), MOCK-03 | 2 | yes |
| 07-06 | **Lint enforcement: `lint-packs.sh` pass H + CI wiring.** Extend `cka-sim/scripts/lint-packs.sh` with new pass H per existing pass header idiom (lines 40, 53, 65, 73, 86, 156, 185). Discover `EXAMS_DIR="${CKA_SIM_LINT_EXAMS_DIR:-$REPO_ROOT/exams}"`, `find -mindepth 2 -name manifest.yaml`, validate per blueprint: count==17, weighting fields present + values 10/15/20/25/30, every (pack, slug) resolves under `cka-sim/packs/<pack>/<slug>/`, no duplicate (pack, slug), sum estimatedMinutes in [120,130], `exam.disclaimer` present + literal MOCK-03 string, README.md contains literal MOCK-03 string. Reuse `_strip_quotes` (line 34), `_in_array` (line 35), error accumulator pattern. Test: `lint_blueprint.sh` (positive + negative fixtures via `CKA_SIM_LINT_EXAMS_DIR`). | 5 | 07-05 | `cka-sim/scripts/lint-packs.sh`, `cka-sim/tests/exam/lint_blueprint.sh`, `cka-sim/tests/fixtures/exam/lint-blueprint/{good,bad-count,bad-weights,bad-dupes,bad-sum,bad-disclaimer}/**` | MOCK-01 (lint), MOCK-03 (lint) | 2 | yes |

**Total tasks across phase:** ~14 (well under chunked-mode 2-3-per-plan ceiling).

---

## Wave Structure

| Wave | Plans | Parallel? | Notes |
|------|-------|-----------|-------|
| 1 | 07-01 | n/a (single plan) | Foundation. Builds Wave-0 fixtures consumed everywhere downstream. |
| 2 | 07-02 | n/a | Report renderer needs `exam-state.sh` schema + Wave-0 fixtures. |
| 3 | 07-03 | n/a | Runtime orchestrator. No file overlap with 07-02 (`exam-report.sh` vs `exam-timer.sh`+`cmd/exam.sh`), but 07-02 is cleaner sequenced for wave clarity since 07-03 transcripts feed report shape. Could be promoted to parallel with 07-02 if scheduling tightens — both depend only on 07-01. |
| 4 | 07-04, 07-05 | yes | 07-04 touches `lib/cmd/{score,list}.sh`; 07-05 touches `exams/blueprint-alpha/`. Zero `files_modified` overlap. 07-05 only needs 07-01's `blueprint::validate`; 07-04 needs 07-02's renderer + 07-03's session shape. |
| 5 | 07-06 | n/a | Lint pass H consumes the manifest 07-05 just authored. |

**Implicit dependency check (file-ownership):**
- `cka-sim/lib/exam-state.sh` — owned by 07-01 only.
- `cka-sim/lib/exam-blueprint.sh` — owned by 07-01 only.
- `cka-sim/lib/exam-report.sh` — owned by 07-02 only.
- `cka-sim/lib/exam-timer.sh` — owned by 07-03 only.
- `cka-sim/lib/cmd/exam.sh` — owned by 07-03 only.
- `cka-sim/lib/cmd/score.sh` — owned by 07-04 only.
- `cka-sim/lib/cmd/list.sh` — owned by 07-04 only.
- `cka-sim/scripts/lint-packs.sh` — owned by 07-06 only.
- `cka-sim/tests/run.sh` — modified once in 07-01 (extend to walk `tests/exam/`); no later plan touches it.

No same-wave file overlaps exist.

---

## Requirement Coverage Audit

Every Phase 7 REQ-ID appears in at least one plan's `requirements` field:

| REQ-ID | Plans | Verification Anchor (from VALIDATION.md) |
|--------|-------|------------------------------------------|
| RUN-03 | 07-03 | `tests/exam/exam_end_to_end.sh` |
| RUN-04 | 07-03 | `tests/exam/timer_render.sh` |
| RUN-05 | 07-01, 07-03 | `tests/exam/state_{atomic_write,schema}.sh`, `tests/exam/exam_resume_after_int.sh` |
| RUN-06 | 07-03 | `tests/exam/signal_handlers.sh` (INT/TSTP/EXIT) |
| MOCK-01 | 07-01 (validate fn), 07-05 (content), 07-06 (lint) | `tests/exam/blueprint_validate.sh`, `lint-packs.sh` pass H, `tests/exam/lint_blueprint.sh` |
| MOCK-03 | 07-05 (content), 07-06 (lint) | `lint-packs.sh` pass H disclaimer sub-rule, `tests/exam/lint_blueprint.sh` |
| REPORT-01 | 07-02 | `tests/exam/report_golden.sh` |
| REPORT-02 | 07-04 | `tests/exam/score_command.sh`, `tests/exam/list_history.sh` |

**Coverage:** 8/8 ✓

---

## CONTEXT Decision Coverage Audit

All 27 locked CONTEXT decisions (D-01..D-27) map to a plan:

| Decision Range | Topic | Plan(s) |
|----------------|-------|---------|
| D-01..D-04 | Timer render + signal handling | 07-03 |
| D-05..D-10 | Session state shape + resume + ~/.cka-sim/ mode 0700 | 07-01 (schema, atomic write, 0700 mkdir), 07-03 (resume mechanics) |
| D-11..D-14 | Question-loop mechanics (reset+setup order, batch grade, no inter-question reset, UI menu, end-of-exam summary) | 07-03 |
| D-15..D-20 | Blueprint composition (17 questions, 120-130 budget, per-domain counts, draw, manifest schema, disclaimer, interleave order) | 07-01 (schema validate), 07-05 (content) |
| D-21..D-25 | Score report layout, sort order, normalization, trap aggregation, next-drills logic | 07-02 |
| D-26..D-27 | `score` + `list history` commands | 07-04 |

**Coverage:** 27/27 ✓

No deferred ideas (DF-02, DF-03, DF-09, HTML/PDF, real-time scores, hints, cross-blueprint comparison) appear in any plan.

---

## RESEARCH Feature Coverage Audit

| RESEARCH §                              | Plan(s) |
|-----------------------------------------|---------|
| Validation Architecture (Nyquist anchors) | All — anchored from VALIDATION.md |
| Architecture & Module Layout (file budget) | All — file-ownership matches RESEARCH §"File breakdown" |
| Critical Implementation Detail 1: Timer subshell + tput | 07-03 |
| Critical Implementation Detail 2: Signal trap composition | 07-03 |
| Critical Implementation Detail 3: Atomic JSON write | 07-01 |
| Critical Implementation Detail 4: Trap parsing | 07-02 (consumed by report) + 07-01 (state recorder) |
| Critical Implementation Detail 5: Per-question grader capture | 07-03 |
| Critical Implementation Detail 6: Batch grade ordering | 07-03 |
| Critical Implementation Detail 7: Resume mechanics | 07-03 |
| Pitfalls 1-15 | Distributed across 07-01 (atomic write, schema versioning, mkdir 0700, jq preflight, exit-code propagation), 07-03 (signal traps, trap re-entrancy, TSTP re-arming, tput corruption, locale sort, no-inter-question-reset safety), 07-02 (locale sort), 07-05 (blueprint estimated-minutes deviation note), 07-06 (lint enforcement) |
| Blueprint-alpha question selection (Final draw — sum 129 min) | 07-05 |
| Test Strategy (case files + fixtures + lint pass H) | 07-01 (foundation tests + Wave-0 fixtures), 07-02 (golden), 07-03 (runtime tests), 07-04 (cmd tests), 07-06 (lint test) |

**Coverage:** all RESEARCH features mapped. No "out of scope" items defer; nothing missed.

---

## Manual-Only Verifications (carried into 07-HUMAN-UAT.md)

Per VALIDATION.md §"Manual-Only Verifications", four behaviors require live human validation and will be authored as `07-HUMAN-UAT.md` during phase verification (not in any plan):

1. Live 2-hour exam end-to-end on real 1+2 cluster (RUN-03..06, MOCK-01).
2. Visible countdown timer rendered correctly on real terminal (RUN-04).
3. Pause via Ctrl-Z + `fg` resumes correctly (RUN-06).
4. Score report readability + suggested-next-drills relevance (REPORT-01).

These are flagged here so the gsd-checker / verifier knows they fall outside the auto-test surface.

---

## Open Items the Planner Will Decide at Plan-Authoring Time

(All within D-17 + RESEARCH §"Open Questions" Claude's discretion — no user decision needed.)

- **Navigation model (RESEARCH OQ 1):** simple forward-only `f`/`s` (recommended) vs full `n`/`p` navigation. Plan 07-03 will pick forward-only unless a strong reason emerges.
- **Pause display string (RESEARCH OQ 2):** `⏱ PAUSED` (recommended) vs `⏱ PAUSED (HH:MM:SS will resume)`.
- **Timer color thresholds (RESEARCH OQ 3):** yellow at 30 min, red at 5 min (recommended) vs no color.
- **`exam --resume` arg style (CONTEXT D-final):** flag-style (`--resume <ts>`) per existing pattern.

---

## OUTLINE COMPLETE

- **Plans:** 6
- **Waves:** 5
- **Phase requirement coverage:** 8/8 ✓
- **CONTEXT decision coverage:** 27/27 ✓
- **No deferred ideas leaked into plans.**
- **No same-wave file-ownership conflicts.**
- **Wave-0 fixtures owned by 07-01; consumed by 07-02 / 07-03 / 07-04 / 07-06.**

Next chunked-mode invocations: author `07-01-PLAN.md` through `07-06-PLAN.md` in plan order. Each plan targets ~50% context with 2-3 tasks (07-01 and 07-03 sit at the upper bound, 3 tasks each; the rest at 2).


Plan: 07-07 Exam Signal Handling Fix
Progress: 2/3 tasks complete

Tasks 1 & 2 are committed in the worktree — all 5 signal-handling defects fixed:
- Defect 1 — read now retries on signal-interrupt (rc>128), only exits on genuine EOF
- Defect 5 — setup.sh wrapped so an interrupted setup flags the question instead of killing the exam
- Defects 2+3 — re-entrancy guard on on_tstp, traps blocked during handler, single on_cont resume path
- Defect 4 — stty save/restore + a gate file that pauses the background timer during read

Awaiting — run this UAT on your live cluster

bash cka-sim/bin/cka-sim exam blueprint-alpha

Then, in order:
1. At >  prompt: Ctrl-C → expect "Q1 flagged. Continuing…" and the >  prompt returns (no exit, no
   "[1]+ Stopped")
2. Ctrl-C 2–3 more times rapidly → each flags + prompt returns; no hang
3. Ctrl-Z → shell shows "[1]+ Stopped" → fg → expect "✓ Resumed." + correct countdown
4. Ctrl-Z, then immediately Ctrl-Z again (nested) → fg → fg → clean resume, timer correct, terminal
   echoes
5. Type n to advance to Q2; during "Setting up Q2..." press Ctrl-Z → fg → Ctrl-C → Ctrl-C again — exam
   stays alive
6. Confirm typing is visible (echo on), then q → y ends and grades normally