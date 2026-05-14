---
status: diagnosed
trigger: "Phase 7 UAT Test 2 — Ctrl-C / Ctrl-Z signal handling: exam stops unexpectedly and hangs unrecoverably on repeated/nested signals"
created: 2026-05-14
updated: 2026-05-14
---

## Current Focus

hypothesis: CONFIRMED — multiple structural defects in signal handling (see Resolution)
test: code read of exam.sh / exam-timer.sh trap + read + job-control logic
expecting: n/a — diagnosis complete
next_action: hand to planner for fix plan

## Symptoms

expected: |
  - Ctrl-C during a question flags current question, persists state, exam CONTINUES (does not die)
  - Ctrl-Z pauses (SIGTSTP); `fg` resumes with correct remaining time
  - Robust to repeated / nested signals and signals during question SETUP phase
actual: |
  Run 1: Ctrl-Z paused OK; `fg` resumed (59:54 remaining); arrow keys; Ctrl-C → "✓ Q1 flagged. Continuing…"
         then shell printed "[1]+  Stopped  bash cka-sim/bin/cka-sim exam blueprint-alpha" — process Stopped unexpectedly.
  Run 2: Ctrl-Z during "Setting up Q1..." (kubectl provisioning running); `fg` resumed (1:59:53);
         then ^C^Z, ^C^C^C^C^C^C, fg, ^C^C^C^C → exam hung with no output, unrecoverable.
errors: none printed — silent hang
reproduction: bash cka-sim/bin/cka-sim exam blueprint-alpha ; press Ctrl-Z, fg, Ctrl-C repeatedly; also press signals during "Setting up Q..." phase
started: discovered Phase 7 UAT 2026-05-14 (signal handling never worked under nesting)

## Eliminated

- hypothesis: "Signal traps are not installed at all"
  evidence: traps ARE installed in question_loop (exam.sh:190-193). They are installed too LATE (not during setup) but they do exist.
  timestamp: 2026-05-14

## Evidence

- timestamp: 2026-05-14
  checked: exam.sh:186-215 question_loop — trap install order vs the work it guards
  found: |
    Traps for INT/TSTP/CONT/EXIT are installed at the TOP of question_loop (lines 190-193),
    but question_loop calls setup_question (line 198) AFTER the traps are installed... however
    start_new()/resume() do other work (timer::spawn, state writes) and the FIRST setup_question
    for Q1 happens INSIDE question_loop so it IS covered. BUT setup_question runs
    `bash "$qdir/setup.sh" </dev/null` (exam.sh:169) as a FOREGROUND child. While that child runs,
    the parent shell is blocked in `wait`. A SIGINT/SIGTSTP from the terminal is delivered to the
    whole foreground process group → the kubectl child gets it too. The parent's trap handler is
    deferred until the foreground child returns. With `set -e` active, if the interrupted child
    exits non-zero the `|| true` on reset.sh saves it but setup.sh (line 169) has NO `|| true` —
    an interrupted setup.sh returns 130 and `set -e` kills the whole exam.
  implication: Signals during the setup phase are not contained; setup.sh failure under `set -e` is unhandled.

- timestamp: 2026-05-14
  checked: exam.sh:209 `if ! read -r action` + on_int handler exam.sh:64-70
  found: |
    on_int flags the question, saves state, prints "✓ QN flagged. Continuing…", returns 0.
    BUT the trap interrupted the `read -r action` builtin. In bash, when a trap fires while
    `read` is blocking, after the handler returns `read` itself returns a NON-ZERO exit status
    (interrupted). Line 209 treats any non-zero read as EOF: `CKA_SIM_EXAM_ENDED=1; break`.
    → Ctrl-C prints "flagged. Continuing…" then immediately ENDS the exam loop and falls into
    confirm_submit. The user sees the flag message but the exam does NOT actually continue.
  implication: Root cause of "Ctrl-C ... it stop for the 1st time" — read is not restarted after the trap.

- timestamp: 2026-05-14
  checked: on_tstp exam.sh:72-79 and on_cont exam.sh:81-86
  found: |
    on_tstp: set_pause; save; timer::stop; `trap - TSTP`; `kill -STOP $$`; then re-arm `trap on_tstp TSTP`.
    Problems:
      1. The re-arm line (78) runs only AFTER the process is CONTinued. Between SIGCONT delivery and
         that line executing, TSTP has default disposition — a second Ctrl-Z in that window stops the
         process with NO state save and NO timer handling.
      2. on_cont (CONT trap) fires on resume and ALSO runs add_pause_delta + timer::spawn. Both
         on_tstp's tail and on_cont run around the same resume event → timer can be double-spawned
         (two redraw_loop background jobs) or pause delta logic races. CKA_SIM_TIMER_PID tracks only
         the last spawn so the earlier timer is leaked/orphaned.
      3. on_tstp does work (jq/mktemp/mv via state::save) that is itself interruptible. A SIGINT or
         SIGTSTP arriving while on_tstp runs re-enters trap handling → nested handlers, partially
         written state, and `kill -STOP $$` possibly never reached → "hung with no output".
      4. `kill -STOP $$` stops only the main shell. The background timer subprocess (redraw_loop)
         is NOT in a stopped state unless timer::stop already killed it; ordering depends on
         whether on_tstp completed. If on_tstp was itself interrupted before timer::stop, the
         timer keeps drawing to the terminal while the shell is stopped.
  implication: Repeated/nested Ctrl-Z and the TSTP/CONT handler pair are the root cause of the
    unrecoverable hang and the "[1]+ Stopped again" after a Ctrl-C.

- timestamp: 2026-05-14
  checked: exam-timer.sh redraw_loop + terminal state
  found: |
    redraw_loop runs tput sc/cup/el/rc and printf directly to the terminal from a background job.
    There is no `stty` save/restore anywhere in the exam runner. After a TSTP/CONT cycle, terminal
    modes (echo, canonical mode) are whatever the kubectl children / job-control left them. If a
    `read` later runs with echo disabled or in a bad mode it blocks with no visible input — matches
    "stuck and haven't replied anything". The background timer also keeps issuing tput escapes
    concurrently with `read`, which can desync the cursor / terminal.
  implication: No terminal-state hygiene around pause/resume; contributes to the silent hang.

- timestamp: 2026-05-14
  checked: on_exit exam.sh:88-100 interaction with on_int-triggered loop end
  found: |
    When Ctrl-C ends the loop (via the read-returns-nonzero bug), control flows to confirm_submit
    which does another bare `read -r confirm`. A further Ctrl-C there interrupts that read too;
    confirm defaults to "y" only on EOF via `|| confirm="y"` — but an interrupted read returns
    non-zero so it WILL default to "y" and proceed to batch_grade unexpectedly, or if interrupted
    again mid-grade the EXIT trap runs reset.sh for every setup question. Cascading unintended
    grading/teardown.
  implication: Secondary fallout — signal during confirm/grade triggers premature grading + teardown.

## Resolution

root_cause: |
  The exam runner's signal handling has four compounding structural defects:

  (1) PRIMARY — `read` is not restarted after a trap. exam.sh:209 `if ! read -r action; then
      CKA_SIM_EXAM_ENDED=1; break`. When the INT trap (on_int) fires during the blocking `read`,
      bash makes `read` return non-zero. The code interprets that as EOF and ENDS the exam. So
      Ctrl-C prints "✓ QN flagged. Continuing…" but then the loop exits — the exam does NOT
      continue. Same defect affects every other `read` (confirm_submit:242).

  (2) on_tstp re-arms the TSTP trap (exam.sh:78) only AFTER `kill -STOP $$` returns, i.e. only
      after resume. During the stop window TSTP has default disposition, so a second Ctrl-Z
      bypasses the handler entirely (no save, no timer stop). on_tstp also performs interruptible
      work (state::save → jq/mktemp/mv) with INT/TSTP still trappable, so a nested signal re-enters
      trap handling and can leave `kill -STOP $$` unreached → unrecoverable hang.

  (3) on_tstp (tail) and on_cont both run around the resume event and both touch the timer
      (timer::stop / timer::spawn) and pause accounting. This races: the timer can be double-spawned
      (orphaned redraw_loop background job) and pause deltas can be mis-applied. CKA_SIM_TIMER_PID
      only remembers the last PID, so leaked timers keep writing tput escapes to the terminal.

  (4) No terminal-state hygiene (no `stty` save/restore) around pause/resume, and the background
      timer writes tput escapes concurrently with foreground `read`. After a TSTP/CONT cycle the
      terminal can be left in non-echo / non-canonical mode, so the next `read` blocks invisibly —
      matching "stuck and haven't replied anything".

  Additionally, signals during the question SETUP phase are uncontained: setup.sh is run as a
  foreground child (exam.sh:169) with no `|| true` and `set -e` active, so an interrupted
  kubectl/setup.sh returns 130 and `set -e` kills the whole exam; the parent's traps are deferred
  until that child returns.

fix: ""  # diagnose-only mode — planner will design the fix
verification: ""
files_changed: []
