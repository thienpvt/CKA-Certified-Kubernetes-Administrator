---
phase: 07-exam-mode-blueprint-alpha-reporting
plan: "03"
backfilled: 2026-05-17
source_commit: 27606bb
---

# 07-03: Exam Orchestrator

## One-Liner
End-to-end exam loop: timer, signal traps, question loop, batch grading, pause/resume.

## What Was Built
- `cka-sim/lib/cmd/exam.sh` — main exam orchestrator
- `cka-sim/lib/exam-timer.sh` — countdown timer with TSTP/INT trap handling
- Question loop: setup → prompt → flag/skip/done → batch grade at end
- Resume from saved state

## Verification
Covered by 07-VERIFICATION.md (RUN-03/04/05/06). Interactive flows validated during Phase 07.1 live exam runs (2026-05-16/17).

## Self-Check: PASSED
