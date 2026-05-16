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

## Re-diagnosis 2026-05-14 — after 07-07 fix (commits dfd9cc5, 30db50f)

The 07-07 fix resolved defects 1, 4, 5 and partially 2/3. UAT re-run #2 confirms
Ctrl-C flag+continue works, rapid Ctrl-C works, single Ctrl-Z/`fg` works. But
**nested Ctrl-Z still hangs unrecoverably** — Test 2 still ❌.

remaining_root_cause: |
  The 07-07 fix kept the structural design of `kill -STOP $$` (last line of on_tstp)
  plus a separate `on_cont` CONT-trap handler for resume. That design cannot survive
  a nested SIGTSTP:

  1. STOP SANDWICH. on_tstp clears its re-entry guard (CKA_SIM_EXAM_IN_SIGHANDLER=0,
     exam.sh:94) and re-arms `trap on_tstp TSTP` (exam.sh:91) BEFORE `kill -STOP $$`
     (exam.sh:96). A SIGTSTP arriving in that few-instruction window re-enters on_tstp.
     Result: two `kill -STOP $$` frames stacked on the call stack, each requiring its
     own `fg`. The re-entry guard is useless because it is cleared before the stop.

  2. on_cont RESETS PAUSED_AT. After the first `fg`, the pending CONT trap runs
     on_cont, which calls add_pause_delta → PAUSED_AT=0. When the second `fg` clears
     the outer stop, on_cont runs again but `(( PAUSED_AT == 0 ))` → early return:
     NO timer respawn, NO "✓ Resumed." printed. The user sees no resume confirmation
     and a `read` that looks dead.

  3. TIMER DRAWS WHILE STOPPED. `kill -STOP $$` stops only the main shell PID, not
     the background redraw_loop. Between the inner resume (on_cont respawns timer B)
     and the outer `kill -STOP $$`, the process stops again WITH timer B running →
     timer keeps issuing tput escapes to the terminal while the shell is stopped →
     garbled display; combined with (2) the terminal appears hung. User must
     force-kill all cka processes.

fix_direction: |
  Replace the `kill -STOP $$` + separate `on_cont` split with the canonical
  self-contained job-control-pause idiom, entirely inside on_tstp:

    on_tstp() {
      (( CKA_SIM_EXAM_IN_SIGHANDLER )) && return
      CKA_SIM_EXAM_IN_SIGHANDLER=1
      trap '' INT TSTP                       # block during cleanup
      set_pause; timer::stop; save; stty restore
      trap - TSTP                            # restore DEFAULT disposition
      kill -TSTP $$                          # kernel does the normal stop
      # ===== execution resumes HERE in-place on SIGCONT (fg) =====
      trap 'cka_sim::exam::on_tstp' TSTP      # re-arm
      trap 'cka_sim::exam::on_int'  INT
      add_pause_delta; save
      CKA_SIM_EXAM_STTY_SAVED=$(stty -g ...)  # re-save
      timer::spawn "$CKA_SIM_EXAM_DEADLINE_TS"
      printf '✓ Resumed.'
      CKA_SIM_EXAM_IN_SIGHANDLER=0
    }

  Key: `kill -TSTP $$` AFTER `trap - TSTP` means the kernel performs the default
  stop (no handler runs, nothing to nest); on SIGCONT execution continues at the
  next line WITHIN THE SAME handler frame. No CONT trap, no second handler, no
  stop sandwich. one `^Z` = one stop = one `fg` = in-place resume.
  Drop `on_cont` entirely OR reduce it to a pure no-op (`return 0`) safety net so a
  stray SIGCONT does nothing. Keep the re-entry guard set across the whole handler
  (it is now genuinely effective because no `kill -STOP` clears the frame early).

## Re-diagnosis 2026-05-14 (#2) — after Task 4 — false premise in Task 1

Task 4's on_tstp rewrite works (single Ctrl-Z + fg resumes in-place). But the Task 5
checkpoint re-run surfaced a SEPARATE defect that was masked all along.

empirical_test: |
  trap 'echo TRAP' INT; ( sleep .3; kill -INT $$ ) & ; read -r x
  → TRAP fires, then `read` BLOCKS AGAIN (test timed out). bash re-issues an
  interrupted `read` in-place after a trapped signal — it does NOT return >128.

root_cause_2: |
  Task 1 was built on a false premise. The Evidence entry claiming "read returns a
  NON-ZERO exit status (interrupted)" is WRONG for the trapped case: with a trap
  installed, bash restarts `read` on EINTR; it only returns non-zero on genuine EOF
  or `-t` timeout. Consequences:
    - The `(( rc > 128 ))` branch in question_loop's retry loop is DEAD code for
      signals — never triggers, so `printf '> '` never re-runs.
    - After Ctrl-C: on_int prints "✓ Q1 flagged. Continuing…", returns; `read`
      silently restarts. No `> ` re-printed → exam looks hung though it still
      accepts input. (UAT re-run #3, step 1.)
    - After Ctrl-Z + fg: on_tstp resumes in-place, prints "✓ Resumed.", returns;
      `read` restarts. Same missing-prompt symptom.
    - on_tstp's timer::stop cleared the timer gate; the respawned timer then drew
      over the (invisible) resumed read prompt.

fix_applied_2: |
  Commit e014e81. Signal handlers now re-print the prompt themselves:
    - New global CKA_SIM_EXAM_PROMPT (default '> '); question_loop sets it to '> ',
      confirm_submit sets it to 'Submit for grading? [y/n] '.
    - on_int re-prints "$CKA_SIM_EXAM_PROMPT" after its flag message.
    - on_tstp re-prints "$CKA_SIM_EXAM_PROMPT" after "✓ Resumed." and calls
      cka_sim::timer::gate_on after timer::spawn so the respawned timer stays
      silent while the restarted `read` owns the terminal.
  Retry loops stay as-is — rc>128 branch is a harmless safety net; the rc==1 EOF
  branch is still needed for piped stdin. Awaiting UAT re-run #4.
