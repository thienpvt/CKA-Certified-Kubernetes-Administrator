---
phase: 07-exam-mode-blueprint-alpha-reporting
plan: 07
title: Gap closure — harden exam signal handling
status: complete
completed: 2026-05-15
requirements: [RUN-04]
commits:
  task_1_2: [dfd9cc5, 30db50f]
  task_4: [949e08b]
  cumulative_chain: [be88426, "...", 62c8c34]
  uat_acks: [7215b0b, f8a2371, 868a586]
---

# Plan 07-07 Summary — Exam Signal-Handling Gap Closure

## Objective

Close Phase 7 UAT Test 2 blocker. The exam runner's signal handling under repeated/nested
Ctrl-Z + Ctrl-C — especially during the kubectl question-setup phase — ended the exam
unexpectedly or hung it unrecoverably.

## Outcome

**UAT Test 2 — PASS (re-run #4, 2026-05-15).** All 6 signal-handling steps pass on live
cluster: Ctrl-C flags + continues, rapid Ctrl-C OK, single Ctrl-Z + `fg` resumes with correct
remaining time, nested Ctrl-Z recoverable, signals during setup recoverable, terminal usable
throughout.

## What changed

### Task 1 — Restartable read + interrupt-contained setup (dfd9cc5, 30db50f)
- `question_loop` and `confirm_submit` read loops distinguish trap-interrupt from genuine EOF.
- `setup_question` wraps `setup.sh` so an interrupted setup flags the current question and
  returns non-zero without killing the exam.

### Task 2 — Re-entrancy-safe TSTP/CONT handlers + stty hygiene + timer gate (dfd9cc5, 30db50f)
- `CKA_SIM_EXAM_IN_SIGHANDLER` re-entry guard, `trap '' INT TSTP` during cleanup.
- stty save in `start_new`/`resume`; restore in pause; re-save in resume.
- exam-timer.sh gate file (`CKA_SIM_TIMER_GATE`); `gate_on`/`gate_off` around every `read`.

### Task 4 — Canonical `trap - TSTP; kill -TSTP $$; in-place resume` idiom (949e08b)
- `on_tstp` rewritten: kernel performs default stop with no handler installed → no nesting,
  no stop sandwich. SIGCONT resumes in-place in the same handler frame; all resume work
  (delta, save, stty re-save, timer respawn, "✓ Resumed.") runs inline.
- `on_cont` reduced to a pure no-op safety net; CONT trap registration kept.
- `kill -STOP` removed from exam.sh.

### Empirical follow-up fixes (re-run #3 → #4 chain, 15 commits be88426 → 62c8c34)
Real-cluster UAT exposed bash-runtime behaviors not predicted statically:
- bash restarts an interrupted `read` in-place after a trapped signal (rc not >128). New
  `CKA_SIM_EXAM_PROMPT` global; `on_int`/`on_tstp` re-print the prompt after their message.
- Stdin drain after signals (prevent buffered Enter from auto-advancing).
- Move `present_question`/state-save OUT of TSTP trap (avoid invisible setup after fg).
- Kill background timer subshell; replace with inline time header + `[t]` query.
- Mask INT during traps; harden jq; check `RESUME_PENDING` after `read`; SIGUSR1 wake-up
  to break the read after `fg`.

### Task 5 — Human UAT (closed 2026-05-15)
Re-run #4 verdict: ✅ PASS. All steps recoverable, terminal usable, timer accurate.

## Files modified

- `cka-sim/lib/cmd/exam.sh` — handlers, read loops, setup containment, prompt re-print, stdin drain
- `cka-sim/lib/exam-timer.sh` — gate, inline header, subshell kill

## Verification

- `bash -n cka-sim/lib/cmd/exam.sh` and `bash -n cka-sim/lib/exam-timer.sh` exit 0
- `bash cka-sim/scripts/test.sh` still passes (no exam-state regression)
- 07-UAT.md Test 2 marked ✅ PASS (re-run #4)

## Closes

- 07-UAT.md Test 2 (signal handling) — ❌ → ✅
- RUN-04 needs-human → satisfied

## Related

- Test 12 (scoring honesty) — acknowledged gap, routed to **Phase 07.1** (commit 868a586).
  Not in scope for this plan.
