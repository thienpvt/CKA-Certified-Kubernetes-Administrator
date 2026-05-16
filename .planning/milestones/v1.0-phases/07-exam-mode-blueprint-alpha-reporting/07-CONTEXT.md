# Phase 7: Exam Mode + Blueprint Alpha + Reporting - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning
**Mode:** Interactive discuss (autonomous mode)

<domain>
## Phase Boundary

Ship the Core Value experience. Implement `cka-sim exam <blueprint>`, `cka-sim score [<ts>]`, and `cka-sim list history` end-to-end. The exam runner loads `exams/blueprint-alpha/manifest.yaml`, drives a 2-hour timed mock against the candidate's 1+2 cluster with flag/skip/return/pause/resume, batch-grades at the end, and renders a Markdown score report under `~/.cka-sim/sessions/<ts>.md`. Blueprint-alpha composes 17 questions by `pack/slug` reference (no duplicated content) across the 5 domain packs shipped in Phases 4–6, weighted 10/30/15/25/20 to the v1.35 CKA blueprint. Phase exits green when a candidate can run the full exam end-to-end on their cluster, see a live timer, flag/skip/pause/resume cleanly, and read a useful Markdown report identifying their weakest domains and most-frequent traps.

</domain>

<decisions>
## Implementation Decisions

### Timer Render and Signal Handling
- **D-01:** Countdown timer is rendered by a **background subshell** that prints `HH:MM:SS remaining` to a dedicated status line every second using `tput sc; tput cup <row> <col>; printf '%s' "$line"; tput rc`. The subshell PID is held in `$CKA_SIM_TIMER_PID`; the EXIT trap kills it. No SIGALRM, no main-loop polling — the timer never blocks input.
- **D-02:** Signal handling per RUN-06: `trap 'cka_sim::exam::on_int' INT` (Ctrl-C → flag current question, persist session.json, return to question prompt; does NOT kill the exam). `trap 'cka_sim::exam::on_tstp' TSTP` (Ctrl-Z → write session.json then `kill -STOP $$` so user can `fg` to resume). `trap 'cka_sim::exam::on_exit' EXIT` (always persist state on normal exit or kill).
- **D-03:** When a session pauses (TSTP), the wall-clock delta from pause-time to resume-time is added to `paused_seconds` in session.json. Remaining-time computation is `deadline_ts - now() + paused_seconds`. This way Ctrl-Z does not "eat" exam time.
- **D-04:** The timer subshell does NOT update during a pause. On resume (`SIGCONT` received by the parent), the parent re-spawns the timer subshell with the recomputed deadline.

### Session State Shape and Resume
- **D-05:** Session state file = single JSON at `~/.cka-sim/sessions/<ts>.json`. Schema fields:
  - `version: 1`
  - `blueprint: { id, path }`
  - `started_at: <iso8601>`
  - `deadline_ts: <unix>`
  - `paused_seconds: <int>`
  - `current_question_idx: <int>`
  - `questions: [{ id, path, pack, domain, idx, status: "pending"|"flagged"|"skipped"|"answered", grade_raw: "<full grade.sh stdout>", score: <int|null>, max_score: <int|null>, traps: ["<trap-id>", ...], started_at, completed_at }]`
  - `final_report_path: <path|null>`
- **D-06:** Parallel transcript log at `~/.cka-sim/sessions/<ts>.log` captures grader stdout/stderr per question (preceded by a `=== question NN: <id> ===` divider). Useful for the candidate to re-read what they saw without re-running the exam. Not consumed by `cka-sim score`.
- **D-07:** Session JSON is rewritten atomically (mktemp + mv) at every state boundary: question_started, flagged, skipped, paused, resumed, graded, exam_completed. Atomic write avoids partial JSON if the candidate kills mid-write.
- **D-08:** Resume strategy (RUN-05): `cka-sim exam --resume <ts>` re-reads session.json, recomputes remaining time from `deadline_ts + paused_seconds - now()`, runs `reset.sh && setup.sh` for `current_question_idx` (idempotent per TRIP-02), restores flagged/skipped sets to their per-question status, then re-enters the question loop. Already-graded questions are NOT re-run.
- **D-09:** If `now() > deadline_ts + paused_seconds`, resume aborts with "Exam expired at <iso8601>" and routes to batch-grade what was completed. The user then gets a partial report.
- **D-10:** `~/.cka-sim/` directory is created on first exam run with mode 0700 (private to the user — session state can include question content the candidate hasn't seen yet for upcoming questions).

### Question-Loop Mechanics
- **D-11:** Per-question orchestration mirrors `drill.sh` order: `reset.sh && setup.sh` BEFORE prompting. End-of-exam batch grading runs `grade.sh` for each question in idx order, capturing stdout into `questions[i].grade_raw`. Inter-question reset between presentations is **not** performed (avoids losing setup work if the candidate flags-and-returns); each question's lab namespace stays alive until exam end.
- **D-12:** End-of-exam batch grading runs `grade.sh` against each question's already-set-up lab namespace. This means cross-question state poison is theoretically possible but each question uses its own `cka-sim-<domain>-NN` namespace per TRIP-03, so isolation is preserved.
- **D-13:** Final cleanup: after batch grading and report rendering, run `reset.sh` for every question that was set up (idempotent). EXIT trap also runs this on abnormal termination.
- **D-14:** Question UI: each question shows `[Question N/17 — domain — estimatedMinutes Xm]` header, the `question.md` body, then a single-line menu: `[Enter]=submit  [f]=flag  [s]=skip  [n]=next  [p]=prev  [q]=end exam`. The candidate works on the cluster in another shell; pressing Enter (or `n`) advances. Flag/skip persist across navigation.

### Blueprint-Alpha Composition (MOCK-01, MOCK-03)
- **D-15:** Blueprint-alpha holds **17 questions** with the **estimatedMinutes budget set to 120–130 min**, NOT 110–120. The phase ships with this deliberate deviation from MOCK-01 because the underlying questions in Phases 4–6 were authored at 6–11 min each, and no 17-question draw across the 5 packs satisfies both 30/25/20/15/10 weighting AND ≤120 min total. The exam timer still runs **2:00:00** countdown; candidates may finish early. The deviation is documented in `exams/blueprint-alpha/README.md` and flagged for ROADMAP amendment in Phase 8.
- **D-16:** Per-domain question counts (matching the v1.35 CKA blueprint weights):
  - Storage 10% → 2 questions
  - Workloads & Scheduling 15% → 3 questions
  - Services & Networking 20% → 3 questions
  - Cluster Architecture 25% → 4 questions
  - Troubleshooting 30% → 5 questions
  - Total: 17 questions ✓
- **D-17:** Specific question selection (Claude's discretion within the per-domain counts): planner picks slugs that maximize topic coverage breadth, prefer questions of moderate difficulty (no all-easy or all-hard draws), and avoid back-to-back questions on the same sub-topic (e.g., do not place two NetworkPolicy questions adjacent). Final selection captured in plan and committed in `exams/blueprint-alpha/manifest.yaml`.
- **D-18:** Manifest schema for `exams/blueprint-alpha/manifest.yaml`:
  ```yaml
  exam:
    id: blueprint-alpha
    version: "1.0"
    durationMinutes: 120  # the actual countdown
    estimatedMinutesBudget: [120, 130]  # documented deviation from MOCK-01 [110, 120]
    weighting: { storage: 10, workloads-scheduling: 15, services-networking: 20, cluster-architecture: 25, troubleshooting: 30 }
    disclaimer: "Not real CKA exam content; independently authored. Targets v1.35 CKA blueprint."
  questions:
    - { pack: storage, slug: 01-pvc-binding }
    - { pack: workloads-scheduling, slug: 04-hpa-metrics-server }
    # ... 15 more
  ```
  Question entries are `pack` + `slug` only (no inline content). Runner resolves to `cka-sim/packs/<pack>/<slug>/` at exam start.
- **D-19:** Blueprint-alpha order: do NOT sort by domain. Interleave domains so the candidate practices context-switching like the real exam. Order is captured in the manifest and is part of blueprint identity (re-running blueprint-alpha = same order; that's what blueprint-bravo is for in Phase 8).
- **D-20:** Blueprint manifest carries the mandatory MOCK-03 disclaimer in its `manifest.yaml` `exam.disclaimer` field AND in `exams/blueprint-alpha/README.md`. Lint enforces both.

### Score Report (REPORT-01, REPORT-02)
- **D-21:** Markdown report layout (written to `~/.cka-sim/sessions/<ts>.md`):
  ```markdown
  # CKA Exam Report — <ts>

  **Blueprint:** blueprint-alpha
  **Started:** <iso8601>  **Completed:** <iso8601>  **Duration:** <hh:mm:ss>
  **Total Score: <N>/100  (<pass|fail> vs 66% pass mark)**

  ## Per-Domain Breakdown (weakest first)

  | Domain | Score | Percentage | Blueprint Weight |
  |---|---|---|---|
  | troubleshooting | 6/15 | 40% | 30% |
  | services-networking | 4/9 | 44% | 20% |
  ...

  ## Top 5 Traps Hit

  | # | Trap ID | Count | Description |
  |---|---|---|---|
  | 1 | service-selector-label-mismatch | 4 | ... |
  ...

  ## Suggested Next Drills

  Your three weakest domains were troubleshooting (40%), services-networking (44%), workloads-scheduling (50%). Drill these next:

  - `cka-sim drill troubleshooting`
  - `cka-sim drill services-networking`
  - `cka-sim drill workloads-scheduling`

  ## Question-by-Question Detail

  | # | Domain | Question | Score | Status | Traps |
  |---|---|---|---|---|---|
  | 1 | storage | 01-pvc-binding | 8/8 | answered | — |
  ...
  ```
- **D-22:** Per-domain table is sorted **percentage ascending** (lowest first per REPORT-01). Score column shows raw points earned / max points across that domain's questions. Percentage = score/max * 100. Weight column displayed for context.
- **D-23:** Total score normalization: each question contributes `(question_score / question_max) * weight_in_blueprint`. Domain weights from `weighting:` in manifest. Total is normalized to /100. Pass mark = 66 (per CKA blueprint).
- **D-24:** Trap aggregation = **raw count** of all `Trap N: <id>` lines emitted across all questions. A single grader emitting the same trap twice contributes 2 to the count. Top-5 selected by raw count desc. Description column pulled from `cka-sim/traps/catalog.yaml` `description` field.
- **D-25:** "Suggested next drills" = **bottom-3 domains by percentage** rendered as `cka-sim drill <pack>` commands. Skip domains where the candidate scored ≥80% (no point drilling what they aced). If fewer than 3 weak domains exist, list whatever bottom domains exist.
- **D-26:** `cka-sim score [<ts>]` re-reads `~/.cka-sim/sessions/<ts>.md` and prints to stdout. With no `<ts>`, lists most recent session and prints its report. With a `<ts>` arg, prints that session's report. If `<ts>.md` is missing but `<ts>.json` exists, regenerate the report from JSON and write `<ts>.md`.
- **D-27:** `cka-sim list history` walks `~/.cka-sim/sessions/*.json`, extracts blueprint id + started_at + total_score, prints a 4-column table sorted by started_at desc. Includes incomplete sessions (with `(in-progress)` marker).

### Claude's Discretion
- Exact bash structure of `lib/cmd/exam.sh` (functions, helper boundaries) — must compose with existing `lib/colors.sh`, `lib/log.sh`, `lib/preflight.sh`. May add `lib/exam-state.sh` for JSON read/write helpers if it keeps `exam.sh` under ~600 lines.
- JSON read/write implementation: jq is allowed (already required by BOOT-07 doctor preflight).
- Specific 17-question slugs for blueprint-alpha (within the per-domain counts and pack-coverage rule).
- Exact byte layout of the status line (e.g., right-aligned vs centered timer) — pick what reads cleanest on an 80-column terminal.
- Whether `cka-sim exam --resume` accepts `<ts>` as positional or flag-only (current pattern is flag-style; stay consistent).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap
- `.planning/ROADMAP.md` §"Phase 7: Exam Mode + Blueprint Alpha + Reporting" — phase goal, requirements RUN-03..06, MOCK-01, MOCK-03, REPORT-01..02, success criteria, dependency on Phase 6.
- `.planning/REQUIREMENTS.md` §"Runner — CLI, timer, session state" — RUN-03, RUN-04, RUN-05, RUN-06.
- `.planning/REQUIREMENTS.md` §"Mock-exam packs" — MOCK-01 (17 questions, weighting, time budget), MOCK-03 (disclaimer).
- `.planning/REQUIREMENTS.md` §"Score report" — REPORT-01 (Markdown layout), REPORT-02 (`cka-sim score`, `cka-sim list history`).

### Prior phase contracts
- `.planning/phases/01-cluster-bootstrap-runner-skeleton/01-CONTEXT.md` — runner CLI dispatcher pattern, `lib/cmd/<name>.sh` module shape, `lib/colors.sh` + `lib/log.sh` conventions.
- `.planning/phases/03-runtime-contract-drill-mode/03-CONTEXT.md` — `cka-sim drill` orchestration order (`reset.sh && setup.sh && prompt && grade.sh`), atomic-write pattern, EXIT-trap reset semantics — exam runner mirrors these.
- `.planning/phases/04-storage-workloads-scheduling-packs/04-CONTEXT.md` — pack manifest shape, `metadata.yaml` schema, lab namespace naming.
- `.planning/phases/05-services-networking-cluster-architecture-packs/05-CONTEXT.md` — pack manifest shape continued.
- `.planning/phases/06-troubleshooting-pack/06-CONTEXT.md` — final pack manifest shape, cross-pack reference convention.

### Code and content anchors
- `cka-sim/lib/cmd/exam.sh` — Phase 1 stub to replace.
- `cka-sim/lib/cmd/score.sh` — Phase 1 stub to replace.
- `cka-sim/lib/cmd/list.sh` — Phase 1 stub to extend with `history` subcommand.
- `cka-sim/lib/cmd/drill.sh` — drill runner to mirror for orchestration order, atomic-write pattern, EXIT-trap discipline.
- `cka-sim/lib/colors.sh`, `cka-sim/lib/log.sh`, `cka-sim/lib/preflight.sh` — shared utilities exam.sh must source.
- `cka-sim/packs/storage/manifest.yaml` — pack manifest schema reference.
- `cka-sim/packs/workloads-scheduling/manifest.yaml` — pack manifest schema reference.
- `cka-sim/packs/services-networking/manifest.yaml` — pack manifest schema reference.
- `cka-sim/packs/cluster-architecture/manifest.yaml` — pack manifest schema reference.
- `cka-sim/packs/troubleshooting/manifest.yaml` — pack manifest schema reference.
- `cka-sim/traps/catalog.yaml` — trap descriptions for the report's top-5 trap table.
- `cka-sim/scripts/lint-packs.sh` — existing lint surface; Phase 7 adds blueprint manifest lint here (no separate script).

### Reference RESEARCH from prior phases (relevant pitfalls)
- `.planning/phases/03-runtime-contract-drill-mode/03-RESEARCH.md` — Pitfall 1 (atomic mktemp+mv), Pitfall 5 (graders source `lib/grade.sh` themselves, not from runner) — both apply to exam.sh.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cka-sim/lib/cmd/drill.sh` — orchestration model exam.sh mirrors (reset → setup → prompt → grade, EXIT trap, atomic write).
- `cka-sim/lib/colors.sh` + `cka-sim/lib/log.sh` — every command sources these for `info`, `warn`, `err`, `ok`, color helpers.
- `cka-sim/lib/preflight.sh` — `cka_sim::preflight::check_kubectl`, `check_jq`, etc. Exam.sh calls these at start.
- `cka-sim/scripts/test.sh` — bash unit harness with PATH-shadowed kubectl/jq stubs. Exam.sh tests live here under `tests/exam/` and `tests/score/`.
- `cka-sim/packs/*/manifest.yaml` — established pack manifest shape; blueprint manifest follows similar `id`/`questions` pattern but with `pack`+`slug` references.

### Established Patterns
- Sub-commands live as `cka-sim/lib/cmd/<name>.sh`, dispatched by `cka-sim/bin/cka-sim`.
- Each sub-command sources `colors.sh` + `log.sh` first; preflights second; main third.
- `set -euo pipefail` at the top of every script.
- `: "${CKA_SIM_ROOT:?}"` guard at top.
- Functions use `cka_sim::<module>::<verb>` namespacing (e.g., `cka_sim::exam::start`).
- Atomic file writes: `mktemp` → write → `mv`.
- All YAML reads done with `yq` if available, falling back to jq via `yq -o json` or pure-bash for catalog parsing (matches Phase 2 pure-bash YAML pattern in `lib/traps.sh`).

### Integration Points
- `cka-sim/bin/cka-sim` already routes `exam`, `score`, `list` subcommands — exam.sh just replaces the stub.
- `~/.cka-sim/` directory used by no other phase; created by exam.sh on first run.
- `traps/catalog.yaml` consumed read-only for the report's trap descriptions.
- Pack `manifest.yaml` files consumed read-only for question metadata (estimatedMinutes, domain).
- Blueprint manifest `exams/blueprint-alpha/manifest.yaml` is NEW.
- `scripts/lint-packs.sh` extended (not duplicated) to lint blueprint manifests too.

</code_context>

<specifics>
## Specific Ideas

- Status line position: bottom row of terminal (`tput lines` minus 1), right-aligned, format `⏱ HH:MM:SS remaining` or `⏱ PAUSED` during pause. Plain ASCII alternative if terminal lacks Unicode.
- The exam header before each question shows `[Question N/17 — <domain> — ~Xm]`. The candidate sees domain to anchor expectations.
- Flag indicator: when a question is flagged, the question header gains `🚩` (or `[F]`). Skipped: `↷` or `[S]`.
- End-of-exam summary screen (before report file is written): show flagged-but-not-answered count + skipped count + remaining-time-when-submitted, ask candidate to confirm submission.
- `cka-sim list history` table columns: `Started`, `Blueprint`, `Score`, `Pass/Fail`, `Status (complete|in-progress)`.
- `tput sc/rc` discipline: any time exam.sh prints to the status line, save cursor first, restore after. Drill output never overlaps the timer.

</specifics>

<deferred>
## Deferred Ideas

- DF-02 trap-frequency aggregation **across sessions** — Phase 7 only aggregates within a single session. Multi-session aggregation is v1.x.
- DF-03 advanced suggested-next-drills routing (e.g., specific question recommendations beyond pack drills) — Phase 7 ships pack-level suggestions only.
- DF-09 retake with re-randomised draw — Phase 7 ships a fixed deterministic blueprint-alpha; re-randomisation is v1.x.
- HTML/PDF score reports — Markdown only.
- Real-time score display during the exam — no, batch-grade at end per RUN-03. Showing scores live would change exam strategy unrealistically.
- Per-question hints during the exam — no, that's drill-mode only and DF-08 keeps hints deferred.
- Cross-blueprint comparison ("you scored 70% on alpha, 65% on bravo") — that's Phase 8 territory once blueprint-bravo exists, and even then it's a v1.x report enhancement.

</deferred>

---

*Phase: 7-Exam Mode + Blueprint Alpha + Reporting*
*Context gathered: 2026-05-13*
