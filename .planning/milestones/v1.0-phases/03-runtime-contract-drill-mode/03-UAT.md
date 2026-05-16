---
status: complete
phase: 03-runtime-contract-drill-mode
source: 03-01-SUMMARY.md through 03-09-SUMMARY.md
started: 2026-05-13T15:31:00Z
updated: 2026-05-13T16:04:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Drill Command Runs a Single Question
expected: Running `cka-sim drill storage` on the CP node creates a lab namespace, presents the question, and on grading emits `SCORE: N/M` plus at least 1 `Trap N:` line when graded against a wrong solution.
result: pass

### 2. Idempotent Re-run (TRIP-02)
expected: Running `cka-sim drill storage` twice in a row never produces `AlreadyExists` errors. The setup is idempotent — namespace and resources are created cleanly each time.
result: pass

### 3. Reference Questions Round-Trip (5 domains)
expected: All 5 reference questions (one per CKA domain) round-trip correctly: setup + grade emits FAIL with ≥1 trap; setup + ref-solution + grade emits PASS (SCORE matches max).
result: pass

### 4. AUTHORING.md Exists
expected: `cka-sim/AUTHORING.md` exists and documents the triplet template (setup/grade/reset), trap registration flow, and lint-packs rule table.
result: pass

### 5. CI Lint Rejects Forbidden Patterns (GRADE-02)
expected: `lint-packs.sh` fails any `grade.sh` containing `kubectl get | grep` or `kubectl get -A`. These patterns are caught by pass A of the lint.
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
