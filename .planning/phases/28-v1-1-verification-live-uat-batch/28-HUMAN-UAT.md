---
status: resolved
phase: 28-v1-1-verification-live-uat-batch
source: [28-VERIFICATION.md]
started: 2026-05-28
updated: 2026-05-28
---

# Phase 28 Human UAT

## Current Test

[testing complete]

## Tests

### 1. Live symptom diff
expected: `cka-sim/scripts/lint-question-symptom.sh dump-cooloo9871/<question>` passes or records accepted live-only limitations for all dump questions.
result: pass
evidence: `cka-sim/scripts/test.sh` live symptom diff passed 61 question(s), including all 30 dump-cooloo9871 questions.

### 2. Empty-submission drill sweep
expected: Empty submissions for dump questions score 0 points.
result: pass
evidence: `cka-sim/current-tests/v11-dump-empty-uat.txt` summary `passed=30 failed=0 total=30`.

### 3. Reference-solution drill sweep
expected: Reference solutions for dump questions reach max score.
result: pass
evidence: `cka-sim/current-tests/v11-dump-uat.txt` summary `passed=30 failed=0 total=30`.

### 4. High-risk operational UAT
expected: Q02/Q04/Q09/Q17/Q18/Q20/Q21/Q25/Q26/Q27 setup, grade, ref, grade, reset loop is recorded on live lab cluster.
result: pass
evidence: Full 30-question live setup -> baseline -> reference solution -> grade -> reset sweep passed; high-risk subset included.

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]
