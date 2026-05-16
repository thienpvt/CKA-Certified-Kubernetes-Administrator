---
phase: 07
phase_name: exam-mode-blueprint-alpha-reporting
status: complete_with_acknowledged_gaps
created: 2026-05-13
last_updated: 2026-05-15
tests_total: 12
tests_passed: 11
tests_acknowledged: 1
tests_failed: 0
tests_skipped: 0
---

# Phase 7 UAT — Exam Mode + Blueprint Alpha + Reporting

## Test Plan

Derived from ROADMAP Phase 7 success criteria + CONTEXT.md decisions.

| # | Test | Criteria | Status |
|---|------|----------|--------|
| 1 | Timer renders during exam | Visible countdown updates every second without blocking input; survives Ctrl-Z pause + fg resume | ✅ |
| 2 | Signal handling (Ctrl-C / Ctrl-Z) | Ctrl-C flags current question + persists state (does NOT kill exam); Ctrl-Z pauses; fg resumes with correct time | ✅ |
| 3a | Blueprint composition — question count | `exams/blueprint-alpha/manifest.yaml` has 17 questions | ✅ |
| 3b | Blueprint composition — lint | `lint-packs.sh` passes all checks | ✅ |
| 4a | Score report — file created | Report at `~/.cka-sim/sessions/<ts>.md` exists after exam run | ✅ |
| 4b | Score report — sections | Report contains Per-Domain Breakdown, Top 5 Traps, Suggested Drills, Total Score | ✅ |
| 4c | Score report — verdict | Report contains PASS/FAIL vs 66% pass mark | ✅ |
| 5a | Score command | `cka-sim score <ts>` displays report with Per-Domain Breakdown | ✅ |
| 5b | List command | `cka-sim list history` shows sessions | ✅ |
| 6a | Blueprint disclaimer — README | README has "Not real CKA exam content; independently authored" | ✅ |
| 6b | Blueprint disclaimer — manifest | manifest.yaml has disclaimer | ✅ |
| 12 | Scoring honesty — empty submission | Empty exam run (no candidate work) MUST score 0/100. Graders must distinguish setup-state from candidate-state. | ⚠ ACK |

---

## Results Log

### Test 3a: Blueprint composition — question count — ✅ PASS (2026-05-13)
- `grep -c 'slug:' exams/blueprint-alpha/manifest.yaml` → 17

### Test 3b: Blueprint composition — lint — ✅ PASS (2026-05-13)
- `lint-packs.sh` passes all checks (263 checks, 0 errors)

### Test 4a: Score report — file created — ✅ PASS (2026-05-13)
- Report file created at `/root/.cka-sim/sessions/20260513T170131Z.md`

### Test 4b: Score report — sections — ✅ PASS (2026-05-13)
- Per-Domain Breakdown, Top 5 Traps Hit, Suggested Next Drills, Total Score all present

### Test 4c: Score report — verdict — ✅ PASS (2026-05-13)
- Report contains "FAIL vs 66% pass mark" (score 11/100)

### Test 5a: Score command — ✅ PASS (2026-05-13)
- `cka-sim score <ts>` outputs report with Per-Domain Breakdown

### Test 5b: List command — ✅ PASS (2026-05-13)
- `cka-sim list history` shows session with blueprint-alpha, score, status

### Test 6a: Blueprint disclaimer — README — ✅ PASS (2026-05-13)
- README.md contains disclaimer string

### Test 6b: Blueprint disclaimer — manifest — ✅ PASS (2026-05-13)
- manifest.yaml contains disclaimer string

### Test 1: Timer renders during exam — ✅ PASS (2026-05-14)
- Countdown timer rendered and updated during exam
- Survived Ctrl-Z pause + `fg` resume — showed correct remaining time (`1:59:53` / `59:54`)

### Test 2: Signal handling (Ctrl-C / Ctrl-Z) — ❌ ISSUE (2026-05-14)
- reported: "when i press Ctrl+Z, it paused, but I press some buttons and Ctrl+C again, it stop for the 1st time. For the second time, it stuck and haven't replied anything until now"
- severity: blocker
- First run: Ctrl-Z paused, `fg` resumed OK, Ctrl-C flagged Q1 and continued, then process showed `[1]+ Stopped` again
- Second run: Ctrl-Z during "Setting up Q1..." (kubectl commands running), `fg` resumed, then repeated `^C^Z` / `^C^C...` / `fg` left the exam **hung with no response** — unrecoverable
- Signals arriving during the question setup phase (kubectl provisioning) are not handled — process group stops mid-kubectl, nested SIGTSTP/SIGINT corrupt state

---

## Bugs Fixed During UAT

| Commit | Issue | Root Cause |
|--------|-------|------------|
| 9ff8312 | cmd scripts not executable | git tracked as 644, `exec` failed |
| 53f0d0b | `cka_sim::preflight::check_jq` undefined | Function never implemented in preflight.sh |
| 4f49f9a | Exam infinite loop on piped stdin EOF | `read` EOF → "(signaled)" → `continue` forever |
| 314cdc0 | Setup/grade scripts consuming piped stdin | Inherited stdin from parent; fixed with `</dev/null` |
| d196d46 | `CKA_SIM_EXAM_QDIRS` empty at runtime | `build_questions_json` ran in `$(...)` subshell, array lost |

---

## Summary

**11/12 tests passed; 1 acknowledged gap (Test 12 — scoring honesty, deferred to new phase).** Test 2 (signal handling) PASSED on re-run #4 after 15 fix commits.

Exam mode runs end-to-end (blueprint loading → grading → reporting). Timer renders correctly. Signal handling robust against repeated/nested Ctrl-C/Ctrl-Z.

**Acknowledged scoring-honesty gap (Test 12):** graders award points for setup-created state — empty submission scored 10/100 (7 raw). Phase 7 ships with this caveat; full rebuild deferred to a new phase (see Acknowledged Gaps below).

## Acknowledged Gaps

- **Test 12 — Scoring honesty:** Routed to new phase per user decision (2026-05-15). README must carry a scoring-honesty caveat noting "current grader scores reflect setup-state in some questions; will be rebuilt in a future phase". The full diagnosis, per-question artifact list, and missing-pieces inventory remain in the Gaps section below as the spec input for the new phase.

## Gaps

- truth: "Empty exam submission scores 0/100; graders distinguish setup-state from candidate-state"
  status: failed
  reason: "User reported: ran exam, typed nothing, ended with q→y. Got 10/100 (7 raw points). Q3 awarded 4/4 free; Q8/Q9/Q11 each got 1 setup-leakage point; multiple traps fired on setup state."
  severity: blocker
  test: 12
  root_cause: "Phase 7 graders use ABSOLUTE end-state assertions that conflate setup-state with candidate-state. Worst class: workloads-scheduling-02 grader checks generation>=3 but setup.sh already bumps generation to >=3 via annotate+patch. Mid-class: storage-02 grader asserts PVC field that setup.sh creates verbatim. Low-class: services-networking-06 'reach :8085' passes via default-allow with no NetworkPolicy. Trap detectors also fire on setup state (e.g., default-sa-used on setup-created Deployment lacking serviceAccountName)."
  artifacts:
    - path: "cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/grade.sh"
      issue: "Asserts deployment exists / rollout complete / image==nginx:1.25 / generation>=3 — all satisfied by setup.sh before candidate input. Need baseline generation + delta check."
    - path: "cka-sim/packs/workloads-scheduling/02-rolling-update-rollback/setup.sh"
      issue: "Performs annotate+patch which bump generation to >=3 — collides with grader assertion 4 threshold."
    - path: "cka-sim/packs/storage/02-storageclass-dynamic/grade.sh"
      issue: "Asserts `pvc.spec.storageClassName == fast-ssd` — but setup.sh writes that exact field. Candidate creating SC has no effect on this assertion."
    - path: "cka-sim/packs/services-networking/06-netpol-endport/grade.sh"
      issue: "Assertion 5 ('client reaches :8085') passes via default-allow when no NetworkPolicy exists. Needs gating: only score reachability assertions AFTER confirming a candidate NetworkPolicy exists."
    - path: "cka-sim/packs/cluster-architecture/04-pss-enforce/grade.sh"
      issue: "1 assertion passes on setup state alone — likely ns label or admission-log artifact created by setup."
    - path: "cka-sim/lib/grade.sh"
      issue: "No baselining primitives. Helpers (assert_resource_exists, assert_field_eq) check absolute state; cannot express 'changed since setup' or 'candidate-authored'."
    - path: "cka-sim/lib/traps.sh"
      issue: "Trap detectors run on setup-state without ownership check — Q3 'default-sa-used' fires on setup's Deployment, not candidate's."
  missing:
    - "Pre-question baseline capture: setup.sh writes /tmp/cka-sim/<question>/baseline.json with generation/labels/resource list AFTER setup completes; grade.sh reads it for delta comparisons."
    - "Convert absolute thresholds to deltas: 'generation >= baseline_gen + 2' not 'generation >= 3'."
    - "Gate side-effect assertions on candidate-authored prerequisites: only assert reachability if candidate's NetworkPolicy exists."
    - "Audit all 17 blueprint-alpha questions: rerun empty submission, identify every assertion that passes without candidate work, classify (setup-collision / default-allow / trap-on-setup)."
    - "Trap detectors must check ownership (e.g., resource was created/modified AFTER setup completed) before scoring."
    - "Add regression test: 'empty submission scores 0' run in CI for every question."
  ui_evidence: "Session 20260515T120747Z report: Total Score: 10/100, Q3=4/4 with status 'failed' (logical contradiction)."
  reason: "User reported: when i press Ctrl+Z, it paused, but I press some buttons and Ctrl+C again, it stop for the 1st time. For the second time, it stuck and haven't replied anything until now"
  severity: blocker
  test: 2
  root_cause: "Four compounding signal-handling defects in exam.sh: (1) PRIMARY — `read` not restarted after trap: exam.sh:209 treats trap-interrupted non-zero `read` as EOF and ends the exam; (2) on_tstp re-arms TSTP trap only after resume and does interruptible state::save work → nested signals deadlock before `kill -STOP $$`; (3) on_tstp tail + on_cont race over timer spawn/stop → orphaned redraw_loop; (4) no stty save/restore + background timer tput collides with foreground read → terminal left in bad mode. Plus setup.sh runs as foreground child (exam.sh:169) with no `|| true` under `set -e` → interrupted setup kills exam."
  artifacts:
    - path: "cka-sim/lib/cmd/exam.sh"
      issue: "read at :209 and :242 treats trap-interrupt as EOF; on_int/on_tstp/on_cont/on_exit (:64-100) re-entrant and racy; setup.sh child at :169 has no `|| true` under set -e"
    - path: "cka-sim/lib/exam-timer.sh"
      issue: "redraw_loop (:14-51) writes tput to terminal from background job with no coordination; CKA_SIM_TIMER_PID (:53-68) tracks only last spawn → leaked timers"
  missing:
    - "Loop `read` until success or genuine EOF; distinguish trap-interrupt from real EOF"
    - "Make on_tstp self-contained and re-entrancy-safe: block INT/TSTP for handler duration, do state work, stop timer, re-arm before `kill -STOP $$`, guard flag against re-entry"
    - "Consolidate pause/resume timer + delta logic into one path (not on_tstp + on_cont racing)"
    - "Add stty save on exam start / restore on resume; gate background timer output while read/pause active"
    - "Wrap setup.sh invocation with `|| true` (or interrupt-aware wrapper) so a signal during setup aborts the question, not the exam"
  debug_session: .planning/debug/exam-signal-handling-hang.md


### Re-run #2 verdict (2026-05-14) — ❌ STILL FAILING (nested Ctrl-Z)

- Steps 1–3 PASS: Ctrl-C flags + continues (no exit, no "[1]+ Stopped"); rapid Ctrl-C OK; single Ctrl-Z → `fg` → "✓ Resumed." with correct time.
- **Step 4 FAILS**: nested Ctrl-Z (`^Z` `^Z` then `fg`) — exam resumes (timer redraws `59:22 remaining`) but `read` never accepts input again. "type anything" does nothing. User had to force-kill all cka processes.
- severity: blocker
- Remaining root cause: the 07-07 fix kept the `kill -STOP $$` + separate `on_cont` design. A second SIGTSTP arriving in the window between on_tstp clearing its re-entry guard (`CKA_SIM_EXAM_IN_SIGHANDLER=0`) and `kill -STOP $$` re-enters on_tstp → "stop sandwich": two `kill -STOP $$` frames stacked, each needs its own `fg`. `on_cont` runs after the FIRST `fg` and resets `PAUSED_AT=0`, so after the SECOND `fg` `on_cont` early-returns — no timer reconcile, no "✓ Resumed.", and the background timer keeps drawing while the main shell is stopped → garbled terminal + apparently-dead `read`.
- Fix direction: replace the `kill -STOP $$` + `on_cont` split with the canonical self-contained idiom inside on_tstp — `trap - TSTP; kill -TSTP $$; trap on_tstp TSTP` — so the kernel does the default stop and execution resumes IN-PLACE in the same handler frame on SIGCONT. No CONT trap, no nesting, no sandwich. Resume work (delta, timer respawn, stty re-save, "Resumed") moves inline after `kill -TSTP $$`; `on_cont` is dropped or reduced to a pure no-op safety net.
- Fix committed: Task 4 (949e08b) — on_tstp canonical idiom, on_cont no-op.

### Re-run #3 verdict (2026-05-14) — ❌ STILL FAILING (different defect — missing prompt)

- Step 1 FAILS: Ctrl-C → `✓ Q1 flagged. Continuing…` prints, but the `> ` prompt does NOT reappear. Exam still accepts input but shows no prompt cue → looks hung.
- New root cause: Task 1's premise was false. Verified empirically — bash **restarts** an interrupted `read` in-place after a trapped signal; it does NOT return >128. So the `rc > 128` branch in the question_loop retry loop is dead code and `printf '> '` never re-runs. Same applies to on_tstp's resume side (`✓ Resumed.` printed, no `> `).
- Fix committed: e014e81 — new global `CKA_SIM_EXAM_PROMPT`; `on_int` and `on_tstp` re-print it after their message; `on_tstp` also re-gates the respawned timer. Awaiting UAT re-run #4.

### Re-run #4 verdict (2026-05-15) — ✅ PASS

- All 6 signal-handling steps pass on live cluster after cumulative fixes through commit 62c8c34.
- Fix chain (15 commits, be88426 → 62c8c34): timer lifecycle, stty save/restore, drain stdin after signals, on_tstp re-display, kill background timer subshell, prompt re-print, mask INT during traps, harden jq, RESUME_PENDING check after fg, SIGUSR1 wake-up.
- Test 2 PASS — exam mode now fully signal-safe.

### Test 12: Scoring honesty — empty submission — ❌ ISSUE (2026-05-15)
- reported: Empty exam run (user did nothing, just `q` → `y`) scored 10/100 weighted, 7 raw points awarded across 4 questions
- severity: blocker (grading credibility — exam mode is for self-assessment)
- Evidence (session `20260515T120747Z`):

| Q | Score | Why awarded without candidate work |
|---|-------|-------------------------------------|
| 3 workloads-scheduling/02-rolling-update-rollback | 4/4 | `setup.sh` creates Deployment at nginx:1.25 + does 2 generation bumps (annotate + patch); grader checks (a) deployment exists, (b) rollout complete, (c) image == nginx:1.25, (d) generation >= 3 — all already true from setup. Question asks: bump to nginx:1.27 → rollback to nginx:1.25 — final state == setup state, grader can't distinguish. |
| 8 services-networking/06-netpol-endport | 1/6 | No NetworkPolicy created → default-allow → "client can reach :8085" assertion passes accidentally |
| 9 cluster-architecture/04-pss-enforce | 1/5 | Setup applies one assertion-matching artifact (likely ns label or admission log) before candidate touches it |
| 11 storage/02-storageclass-dynamic | 1/3 | `setup.sh` creates PVC with `storageClassName: fast-ssd` → "PVC references fast-ssd" assertion passes from setup alone |

- Plus traps fired on setup state (e.g., Q3 "default-sa-used" — deployment in setup has no `serviceAccountName`, trap detector fires on setup state before user does anything).
- Root cause class: **absolute end-state assertions** that conflate setup-state with candidate-state. No grader baselines pre-candidate generation/labels/resources.

