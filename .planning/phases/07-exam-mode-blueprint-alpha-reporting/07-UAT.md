---
phase: 07
phase_name: exam-mode-blueprint-alpha-reporting
status: diagnosed
created: 2026-05-13
last_updated: 2026-05-14
tests_total: 11
tests_passed: 10
tests_failed: 1
tests_skipped: 0
---

# Phase 7 UAT — Exam Mode + Blueprint Alpha + Reporting

## Test Plan

Derived from ROADMAP Phase 7 success criteria + CONTEXT.md decisions.

| # | Test | Criteria | Status |
|---|------|----------|--------|
| 1 | Timer renders during exam | Visible countdown updates every second without blocking input; survives Ctrl-Z pause + fg resume | ✅ |
| 2 | Signal handling (Ctrl-C / Ctrl-Z) | Ctrl-C flags current question + persists state (does NOT kill exam); Ctrl-Z pauses; fg resumes with correct time | ❌ |
| 3a | Blueprint composition — question count | `exams/blueprint-alpha/manifest.yaml` has 17 questions | ✅ |
| 3b | Blueprint composition — lint | `lint-packs.sh` passes all checks | ✅ |
| 4a | Score report — file created | Report at `~/.cka-sim/sessions/<ts>.md` exists after exam run | ✅ |
| 4b | Score report — sections | Report contains Per-Domain Breakdown, Top 5 Traps, Suggested Drills, Total Score | ✅ |
| 4c | Score report — verdict | Report contains PASS/FAIL vs 66% pass mark | ✅ |
| 5a | Score command | `cka-sim score <ts>` displays report with Per-Domain Breakdown | ✅ |
| 5b | List command | `cka-sim list history` shows sessions | ✅ |
| 6a | Blueprint disclaimer — README | README has "Not real CKA exam content; independently authored" | ✅ |
| 6b | Blueprint disclaimer — manifest | manifest.yaml has disclaimer | ✅ |

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

**10/11 tests passed. 1 issue found (Test 2 — signal handling).**

Exam mode runs end-to-end (blueprint loading → grading → reporting). Timer renders correctly. Signal handling is broken: repeated/nested Ctrl-Z + Ctrl-C — especially during the kubectl question-setup phase — hangs the exam unrecoverably.

## Gaps

- truth: "Ctrl-C flags current question + persists state without killing exam; Ctrl-Z pauses; fg resumes — robust to repeated/nested signals and signals during question setup"
  status: failed
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

### Test 2 response
## current state
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

## results from cluster
```
root@master:~# cka-sim exam blueprint-alpha
  Loading blueprint: blueprint-alpha
  Questions: 17
  Duration: 120 minutes
  Session: 20260514T142958Z
  Starting exam...

  Setting up Q1...
namespace/cka-sim-storage-01 created
persistentvolume/q01-app-pv created
persistentvolumeclaim/app-data created

[Question 1/17 — storage — ~8m]
─────────────────────────────────────────
# storage/01-pvc-binding

**Domain:** Storage  |  **Estimated time:** 8 minutes

A `PersistentVolumeClaim` named `app-data` exists in your lab namespace and references a `PersistentVolume` named `q01-app-pv`. The PVC is stuck `Pending`.

## Tasks

1. Inspect the PVC `app-data` in `${CKA_SIM_LAB_NS}` and the PV `q01-app-pv` (cluster-scoped).
2. Diagnose why the PVC is not binding. Read the PV spec and events carefully.
3. Modify the PV in place so the PVC can bind successfully.

## Constraints

- Do NOT delete or recreate the PV — modify it in place.
- Do NOT modify the PVC.
- The lab cluster has 1 control-plane + 2 worker nodes. The PV must remain usable on any worker.

## Verify yourself

Before typing `done`, confirm:

```
kubectl get pvc app-data -n ${CKA_SIM_LAB_NS}    # STATUS should be Bound
kubectl get pv q01-app-pv                        # STATUS should be Bound
```

[Enter/n]=next  [f]=flag  [s]=skip  [p]=prev  [q]=end exam
> ^C
✓ Q1 flagged. Continuing…
return
! Unknown action: 'return'. Use Enter/n/f/s/p/q.

[Question 1/17 — storage — ~8m] 🚩
─────────────────────────────────────────
# storage/01-pvc-binding

**Domain:** Storage  |  **Estimated time:** 8 minutes

A `PersistentVolumeClaim` named `app-data` exists in your lab namespace and references a `PersistentVolume` named `q01-app-pv`. The PVC is stuck `Pending`.

## Tasks

1. Inspect the PVC `app-data` in `${CKA_SIM_LAB_NS}` and the PV `q01-app-pv` (cluster-scoped).
2. Diagnose why the PVC is not binding. Read the PV spec and events carefully.
3. Modify the PV in place so the PVC can bind successfully.

## Constraints

- Do NOT delete or recreate the PV — modify it in place.
- Do NOT modify the PVC.
- The lab cluster has 1 control-plane + 2 worker nodes. The PV must remain usable on any worker.

## Verify yourself

Before typing `done`, confirm:

```
kubectl get pvc app-data -n ${CKA_SIM_LAB_NS}    # STATUS should be Bound
kubectl get pv q01-app-pv                        # STATUS should be Bound
```

[Enter/n]=next  [f]=flag  [s]=skip  [p]=prev  [q]=end exam
> ^C
✓ Q1 flagged. Continuing…
^C
✓ Q1 flagged. Continuing…
^C
✓ Q1 flagged. Continuing…
return
! Unknown action: 'return'. Use Enter/n/f/s/p/q.

[Question 1/17 — storage — ~8m] 🚩
─────────────────────────────────────────
# storage/01-pvc-binding

**Domain:** Storage  |  **Estimated time:** 8 minutes

A `PersistentVolumeClaim` named `app-data` exists in your lab namespace and references a `PersistentVolume` named `q01-app-pv`. The PVC is stuck `Pending`.

## Tasks

1. Inspect the PVC `app-data` in `${CKA_SIM_LAB_NS}` and the PV `q01-app-pv` (cluster-scoped).
2. Diagnose why the PVC is not binding. Read the PV spec and events carefully.
3. Modify the PV in place so the PVC can bind successfully.

## Constraints

- Do NOT delete or recreate the PV — modify it in place.
- Do NOT modify the PVC.
- The lab cluster has 1 control-plane + 2 worker nodes. The PV must remain usable on any worker.

## Verify yourself

Before typing `done`, confirm:

```
kubectl get pvc app-data -n ${CKA_SIM_LAB_NS}    # STATUS should be Bound
kubectl get pv q01-app-pv                        # STATUS should be Bound
```

[Enter/n]=next  [f]=flag  [s]=skip  [p]=prev  [q]=end exam
> ^Z
[1]+  Stopped                 cka-sim exam blueprint-alpha
root@master:~# fg
cka-sim exam blueprint-alpha

✓ Resumed.
^Z^Zfg59:22 remaining
fg
n
^Z
fg
^C
^C
q
y

```

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

