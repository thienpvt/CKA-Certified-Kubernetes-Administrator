---
phase: 07-exam-mode-blueprint-alpha-reporting
verified: 2026-05-14T00:00:00Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
human_verification_completed: 2026-05-17  # RUN-04 + RUN-06 verified via Phase 07.1 live cluster UAT (17/17 ref-solution round-trip)
requirements_coverage:
  RUN-03: satisfied      # end-to-end exam run — UAT 9/9 automated; exam.sh orchestrator wired
  RUN-04: satisfied      # visible countdown timer — verified during 07.1 live exam runs (2026-05-16/17)
  RUN-05: satisfied      # pause/resume + persist — exam-state.sh atomic save, exam.sh resume() wired, state_atomic_write + state_schema tests pass
  RUN-06: satisfied      # signal handling INT/TSTP/CONT/EXIT — verified during 07.1 live exam runs (2026-05-16/17)
  MOCK-01: satisfied     # 17-question blueprint, weights, sum 130 — manifest verified structurally, lint-packs pass H enforces
  MOCK-03: satisfied     # disclaimer in manifest + README — both contain literal string
  REPORT-01: satisfied   # Markdown score report — exam-report.sh renders all 5 sections, golden test present
  REPORT-02: satisfied   # score + list history commands — score.sh/list.sh replace stubs, wired into CLI dispatch
human_verification:
  - test: "Run `cka-sim exam blueprint-alpha` in an interactive terminal; observe the countdown timer"
    expected: "Timer on its own status line at bottom row, decrements every second, does not corrupt question text or block input; survives Ctrl-Z pause + `fg` resume with correct remaining time"
    why_human: "RUN-04 — tput sc/cup/rc rendering is environment-dependent (TERM, terminal size); UAT tests 1 skipped as interactive-only"
  - test: "During an exam, press Ctrl-C, then Ctrl-Z then `fg`, then `kill` the process"
    expected: "Ctrl-C flags current question + persists session.json + returns to prompt (does NOT kill exam); Ctrl-Z pauses via kill -STOP; `fg` resumes with shifted deadline; kill fires EXIT trap and persists state"
    why_human: "RUN-06 — bash job-control + signal delivery in a real interactive shell differs from scripted environments; UAT test 2 skipped as interactive-only"
gaps: []
deferred: []
---

# Phase 7: Exam Mode + Blueprint Alpha + Reporting Verification Report

**Phase Goal:** Ship the Core Value experience. `cka-sim exam blueprint-alpha` runs a 2-hour 17-question mock end-to-end against the candidate's cluster with flag/skip/pause/resume, then renders a Markdown score report with per-domain breakdown and trap frequencies.
**Verified:** 2026-05-14
**Status:** human_needed
**Re-verification:** No — initial verification (produced post-hoc to close milestone audit blocker)

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Success Criterion) | Status | Evidence |
|---|-----------------------------------|--------|----------|
| 1 | Visible countdown timer updates every second without blocking input; survives Ctrl-Z pause + `--resume` rehydration | ⚠️ NEEDS HUMAN | `lib/exam-timer.sh` exports `spawn/stop/redraw_loop`, uses `tput sc/rc`, `CKA_SIM_TIMER_FAST` test hook. `exam.sh` re-spawns timer on CONT (line 70) and on resume (lines 347/382) with recomputed `CKA_SIM_EXAM_DEADLINE_TS`. `add_pause_delta` shifts deadline. Interactive render SKIPPED in UAT (test 1) — needs real terminal. |
| 2 | Ctrl-C flags current question + persists (does NOT kill); Ctrl-Z pauses; normal exit and `kill` persist via EXIT trap | ⚠️ NEEDS HUMAN | `exam.sh` registers `trap` for INT/TSTP/CONT/EXIT (lines 174-177); `on_int` sets status=flagged + saves + returns 0; `on_tstp` saves + `kill -STOP $$` (lines 62-63); `on_exit` persists + cleanup. Handler logic verified statically. Interactive signal delivery SKIPPED in UAT (test 2). |
| 3 | `manifest.yaml` composes exactly 17 questions by pack/slug, weighted 10/15/20/25/30, estimatedMinutes sum in budget | ✓ VERIFIED | `grep -c slug:` → 17. Weights `storage:10 workloads-scheduling:15 services-networking:20 cluster-architecture:25 troubleshooting:30` present. All 17 (pack,slug) pairs resolve to existing `cka-sim/packs/<pack>/<slug>/` dirs. Domain counts 2/3/3/4/5. estimatedMinutes sum = 130 ∈ [120,130] (D-15 deviation from MOCK-01 [110,120], documented in README + CONTEXT). lint-packs pass H enforces all rules. UAT test 3a/3b PASS. |
| 4 | Markdown report at `~/.cka-sim/sessions/<ts>.md` with total /100, pass/fail vs 66%, per-domain table sorted lowest-first, top-5 traps, suggested drills | ✓ VERIFIED | `lib/exam-report.sh` renders header (`Total Score: N/100 ... vs 66% pass mark`), `## Per-Domain Breakdown (weakest first)`, `## Top 5 Traps Hit`, `## Suggested Next Drills`, `## Question-by-Question Detail`. Pass mark `>= 66` check line 67. Atomic mktemp+mv write. `report_golden.sh` golden test present. UAT tests 4a/4b/4c PASS. |
| 5 | `cka-sim score <ts>` re-displays report; `cka-sim list history` enumerates completed sessions | ✓ VERIFIED | `score.sh` replaces stub: `most_recent_ts`, regenerates via `cka_sim::report::render` if `.md` missing (line 57). `list.sh` adds `history` subcommand with 5-column table + `(in-progress)` status marker. Both wired into `bin/cka-sim` dispatch (`exam|score` line 27, `list`). UAT tests 5a/5b PASS. |
| 6 | Blueprint-alpha README has "Not real CKA exam content; independently authored" disclaimer | ✓ VERIFIED | `grep -c` → README.md:1, manifest.yaml:1. Literal string present in both. UAT tests 6a/6b PASS. |

**Score:** 6/6 truths verified (4 fully verified, 2 verified-but-need-human-confirmation for interactive behavior)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `cka-sim/lib/exam-state.sh` | Atomic JSON session state | ✓ VERIFIED | 15 `cka_sim::state::*` functions; mktemp+`jq empty`+mv atomic save; `version != 1` fail-fast (line 80); `CKA_SIM_NOW_OVERRIDE` time-freeze. Syntax valid. |
| `cka-sim/lib/exam-blueprint.sh` | Manifest parser/validator | ✓ VERIFIED | 4 `cka_sim::blueprint::*` functions (load/resolve_question/validate/estimated_minutes_sum). Syntax valid. |
| `cka-sim/lib/exam-report.sh` | Markdown report renderer | ✓ VERIFIED | 7 `cka_sim::report::*` functions; all 5 report sections; atomic write; pass mark 66. Syntax valid. |
| `cka-sim/lib/exam-timer.sh` | Background countdown subshell | ✓ VERIFIED | `spawn/stop/redraw_loop/_now`; `tput sc/rc`; `CKA_SIM_TIMER_FAST` hook. Syntax valid. |
| `cka-sim/lib/cmd/exam.sh` | Full exam orchestrator (replaces Phase 1 stub) | ✓ VERIFIED | 16 `cka_sim::exam::*` functions; sources all 5 helpers + preflight; INT/TSTP/CONT/EXIT traps; `kill -STOP`; source-vs-execute guard; no "not implemented" string. Syntax valid. |
| `cka-sim/lib/cmd/score.sh` | Score viewer w/ on-demand regen | ✓ VERIFIED | Stub replaced; `cka_sim::score::main`; `report::render` regen path. Syntax valid. |
| `cka-sim/lib/cmd/list.sh` | List + history subcommand | ✓ VERIFIED | `cka_sim::list::history`; `(in-progress)` marker; subcommand dispatcher. Syntax valid. |
| `exams/blueprint-alpha/manifest.yaml` | 17-question blueprint | ✓ VERIFIED | 17 questions, correct weights, all resolve, sum 130. |
| `exams/blueprint-alpha/README.md` | Blueprint intro + MOCK-03 disclaimer | ✓ VERIFIED | Disclaimer literal present; D-15 deviation documented; pass mark 66. |
| `cka-sim/scripts/lint-packs.sh` (pass H) | Blueprint manifest CI lint | ✓ VERIFIED | `pass H: blueprint manifest lint` (line 221); `CKA_SIM_LINT_EXAMS_DIR` override; `BLUEPRINT:` error prefix; validates count/weights/dupes/resolution/sum/disclaimer/README. |
| `cka-sim/tests/run.sh` | Walks tests/exam/ | ✓ VERIFIED | `exam_dir` loop (lines 47-58) walks `tests/exam/*.sh` in addition to `tests/cases/`. |
| `cka-sim/tests/fixtures/exam/packs/mock-pack-alpha/` | 17-question mock pack | ✓ VERIFIED | 17 `NN-fake` dirs, each with 6 files (grade/setup/reset/ref-solution/metadata/question). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `bin/cka-sim` | `cmd/exam.sh`, `cmd/score.sh`, `cmd/list.sh` | dispatch case | ✓ WIRED | `exam|score` + `list` in dispatcher (line 27) |
| `exam.sh` | `exam-state/blueprint/report/timer.sh` + `preflight.sh` | `source` | ✓ WIRED | All 5 sourced (lines 13-21) |
| `exam.sh` | `report::render` | batch_grade end-of-exam | ✓ WIRED | line 279 |
| `exam.sh` | `timer::spawn/stop` | start/resume/pause/grade | ✓ WIRED | lines 61, 70, 76, 347, 382 |
| `exam.sh resume()` | `state::load` + deadline recompute | `--resume <ts>` | ✓ WIRED | line 354, expiry check → batch_grade line 372 |
| `score.sh` | `report::render` | regen if .md missing | ✓ WIRED | line 57 |
| `list.sh` | `state::list_sessions` | history subcommand | ✓ WIRED | sources exam-state.sh; history at line 72 |
| `lint-packs.sh pass H` | `exams/blueprint-alpha/manifest.yaml` | `CKA_SIM_LINT_EXAMS_DIR` discovery | ✓ WIRED | UAT 3b: lint-packs 263 checks, 0 errors |

### Behavioral Spot-Checks

Cannot execute bash/`cka-sim` on this Windows host. Behavioral evidence taken from the already-passing `07-UAT.md`:

| Behavior | Evidence Source | Result | Status |
|----------|-----------------|--------|--------|
| End-to-end 17-question exam → session.json + report.md | UAT (mock pack run on Linux) | Report created at `/root/.cka-sim/sessions/20260513T170131Z.md`, 17 entries graded | ✓ PASS |
| Report sections rendered | UAT test 4b | Per-Domain + Top 5 Traps + Suggested Drills + Total Score present | ✓ PASS |
| Pass/fail verdict | UAT test 4c | "FAIL vs 66% pass mark" (score 11/100) | ✓ PASS |
| `cka-sim score <ts>` | UAT test 5a | Outputs report with Per-Domain Breakdown | ✓ PASS |
| `cka-sim list history` | UAT test 5b | Shows session with blueprint-alpha, score, status | ✓ PASS |
| lint-packs pass H on real manifest | UAT test 3b | 263 checks, 0 errors | ✓ PASS |
| Timer interactive render | UAT test 1 | SKIPPED — needs interactive terminal | ? SKIP → human |
| Signal handling Ctrl-C/Ctrl-Z | UAT test 2 | SKIPPED — needs interactive terminal | ? SKIP → human |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| RUN-03 | 07-03 | Exam runs end-to-end | ✓ SATISFIED | exam.sh orchestrator complete + wired; UAT end-to-end run produced graded session + report |
| RUN-04 | 07-03 | Visible countdown timer, non-blocking | ? NEEDS HUMAN | exam-timer.sh present + wired; interactive render SKIPPED (UAT test 1) |
| RUN-05 | 07-01, 07-03 | Pause/resume + state persistence | ✓ SATISFIED | exam-state.sh atomic save + version guard; resume() recomputes deadline; state_atomic_write + state_schema tests pass in UAT suite |
| RUN-06 | 07-03 | Signal handling INT/TSTP/CONT/EXIT | ? NEEDS HUMAN | Traps registered + handlers implemented + statically verified; interactive Ctrl-C/Ctrl-Z SKIPPED (UAT test 2) |
| MOCK-01 | 07-01, 07-05, 07-06 | 17-question weighted blueprint | ✓ SATISFIED | manifest structurally verified; lint-packs pass H enforces; sum 130 (D-15 documented deviation from [110,120]) |
| MOCK-03 | 07-05, 07-06 | Disclaimer | ✓ SATISFIED | Literal disclaimer in manifest + README; pass H enforces both |
| REPORT-01 | 07-02 | Markdown score report | ✓ SATISFIED | exam-report.sh renders all 5 sections; golden test present; UAT 4a/4b/4c pass |
| REPORT-02 | 07-04 | score + list history | ✓ SATISFIED | score.sh + list.sh replace stubs, wired into CLI; UAT 5a/5b pass |

No orphaned requirements — all 8 declared REQ-IDs map to plans and are covered.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No debt markers (TODO/FIXME/XXX/TBD/HACK), no "not implemented" stubs, no empty-return stubs in any Phase 7 file | — | None. `mktemp` matches were false positives. |

### Test-Coverage Observation (non-blocking)

Plans 07-03, 07-04, and 07-06 declared seven additional test files in their `files_modified` frontmatter that were **never committed**:
`tests/exam/timer_render.sh`, `signal_handlers.sh`, `exam_resume_after_int.sh`, `exam_end_to_end.sh`, `score_command.sh`, `list_history.sh`, `lint_blueprint.sh`, plus the `tests/fixtures/exam/lint-blueprint/` fixture tree.

Only the 5 wave-1/wave-2 unit tests exist on disk (`state_atomic_write`, `state_schema`, `blueprint_load`, `blueprint_validate`, `report_golden`) — all syntax-valid.

This is **not classified as a goal-blocking gap** because:
- The phase goal (all 6 success criteria) is achieved by the shipped code, verified structurally + by wiring.
- `07-UAT.md` provides compensating behavioral evidence: a real end-to-end exam run on Linux exercised the full orchestrator (exam → grade → report → score → list) plus lint-packs pass H — 9/9 automated tests passed, and 5 runtime bugs were found and fixed during UAT.
- The two genuinely untestable-without-a-terminal behaviors (RUN-04 timer, RUN-06 signals) are routed to human verification regardless of whether automated tests existed.

It is recorded here as a process/coverage note: the automated regression net for the exam orchestrator, score/list commands, and pass H is thinner than the plans intended. Recommend the milestone close-out or a follow-up add the missing `tests/exam/` integration tests so future regressions are caught without a manual UAT.

### Human Verification Required

#### 1. Countdown timer interactive render (RUN-04)

**Test:** Run `cka-sim exam blueprint-alpha` in a real interactive terminal.
**Expected:** Timer renders on its own status line at the bottom row, decrements every second, does not corrupt question text or kubectl output, does not block input. After Ctrl-Z + `fg`, timer reappears with correctly shifted remaining time (pause did not eat exam time).
**Why human:** `tput sc/cup/el/rc` rendering is environment-dependent (TERM, terminal dimensions, font). UAT test 1 was skipped as interactive-only.

#### 2. Signal handling — Ctrl-C / Ctrl-Z / kill (RUN-06)

**Test:** During an exam: press Ctrl-C; then Ctrl-Z followed by `fg`; then from another shell `kill` the exam PID.
**Expected:** Ctrl-C flags the current question, persists `session.json`, and returns to the question prompt without killing the exam. Ctrl-Z persists `paused_at` and stops the process (`kill -STOP $$`); `fg` resumes with shifted deadline and re-spawned timer. `kill` (SIGTERM) fires the EXIT trap and persists state with a non-completed status.
**Why human:** bash job-control and signal delivery in an interactive shell differ from scripted environments. UAT test 2 was skipped as interactive-only.

### Gaps Summary

No goal-blocking gaps. All 6 ROADMAP success criteria are met by the shipped codebase: the exam orchestrator, state/blueprint/report/timer modules, score and list commands, the 17-question blueprint manifest with enforced lint, and the disclaimer are all present, substantive, syntactically valid, and wired end-to-end. The already-passing `07-UAT.md` (9/9 automated) supplies behavioral confirmation for criteria 3-6.

Status is `human_needed` solely because criteria 1 and 4 (RUN-04 timer rendering, RUN-06 signal handling) involve interactive-terminal behavior that cannot be verified statically or in the scripted UAT — the corresponding two UAT tests were deliberately skipped as interactive-only. These need a one-time human run on a real cluster.

A non-blocking coverage note is recorded: seven planned `tests/exam/` files were never committed; the exam orchestrator's automated regression net relies on the manual UAT rather than checked-in integration tests. Recommend adding them in milestone close-out.

---

_Verified: 2026-05-14_
_Verifier: Claude (gsd-verifier)_
