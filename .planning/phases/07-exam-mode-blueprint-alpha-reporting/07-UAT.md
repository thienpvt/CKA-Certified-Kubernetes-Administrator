---
phase: 07
phase_name: exam-mode-blueprint-alpha-reporting
status: passed
created: 2026-05-13
last_updated: 2026-05-13
tests_total: 9
tests_passed: 9
tests_failed: 0
tests_skipped: 2
---

# Phase 7 UAT — Exam Mode + Blueprint Alpha + Reporting

## Test Plan

Derived from ROADMAP Phase 7 success criteria + CONTEXT.md decisions.

| # | Test | Criteria | Status |
|---|------|----------|--------|
| 1 | Timer renders during exam | Visible countdown updates every second without blocking input; survives Ctrl-Z pause + fg resume | ⬜ manual |
| 2 | Signal handling (Ctrl-C / Ctrl-Z) | Ctrl-C flags current question + persists state (does NOT kill exam); Ctrl-Z pauses; fg resumes with correct time | ⬜ manual |
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

### Tests 1 & 2: Timer + Signals — ⬜ SKIPPED (interactive)
- Requires manual verification in interactive terminal
- Instructions: `bash cka-sim/bin/cka-sim exam blueprint-alpha`

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

**9/9 automated tests passed. 2 interactive tests skipped (timer/signals require manual terminal).**

Phase 7 UAT complete. Exam mode runs end-to-end: blueprint loading → question presentation → grading → report generation → score/list commands all functional.
