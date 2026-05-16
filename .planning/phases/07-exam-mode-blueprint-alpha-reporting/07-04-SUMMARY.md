---
phase: 07-exam-mode-blueprint-alpha-reporting
plan: "04"
backfilled: 2026-05-17
source_commit: f7afadc
---

# 07-04: Score + List History Commands

## One-Liner
`cka-sim score` and `cka-sim list` subcommands — view current exam score and historical session list.

## What Was Built
- `cka-sim/lib/cmd/score.sh` — read latest session, render summary
- `cka-sim/lib/cmd/list.sh` — list `~/.cka-sim/sessions/` markdown files
- Wired into CLI dispatch in `cka-sim`

## Verification
Covered by 07-VERIFICATION.md (REPORT-02 satisfied).

## Self-Check: PASSED
