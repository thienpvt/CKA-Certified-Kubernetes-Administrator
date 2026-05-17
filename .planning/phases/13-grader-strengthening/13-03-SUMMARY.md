---
phase: 13-grader-strengthening
plan: 03
status: complete
requirements: [BUG-M06]
files_modified:
  - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/grade.sh
---

# Plan 13-03 Summary — BUG-M06 workloads-scheduling/04-hpa-metrics-server

## What changed

- **grade.sh** — Two surgical edits:
  1. Updated the assertion-list header comment to list 7 assertions and note
     Phase 13 BUG-M06.
  2. Inserted Assertions 5 and 6 immediately after Assertion 4, using the same
     `assert_field_eq` helper and the same `[?(@.type=="Resource")]` jsonpath
     filter shape. Renumbered the existing behavioural check from Assertion 5
     to Assertion 7 (comment-only — body unchanged).
- Assertions 1-4, behavioural retry/sleep loop, `CKA_SIM_GRADE_TOP_RETRIES` /
  `CKA_SIM_GRADE_TOP_SLEEP` env overrides, `top_ok` flag, trap detector, and
  `cka_sim::grade::emit_result` finalizer all preserved verbatim.

## Scoring shape

| Submission                              | Score | Notes                              |
| --------------------------------------- | ----- | ---------------------------------- |
| Ref-solution (Utilization, 50)          | 7/7   | + 0 traps                          |
| Empty (no HPA)                          | 0/7   | A1 fails resource-authored gate    |
| averageUtilization: 80                  | 6/7   | A6 fails                           |
| target.type: AverageValue + averageValue| 5/7   | A5 + A6 both fail                  |

## Verification status

- `bash -n grade.sh` exits 0.
- Acceptance greps all positive:
  - Phase 13 BUG-M06 marker: 1
  - `.resource.target.type}` field: 1
  - `'Utilization' -n` literal: 1
  - `.resource.target.averageUtilization}` field: 1
  - `'50' -n` literal: 1
  - `[?(@.type=="Resource")]` filter shape: 3 (A4 + A5 + A6)
  - Assertion 7 header: 1; old "Assertion 5: behavioural" comment: 0
  - `CKA_SIM_GRADE_TOP_RETRIES` / `CKA_SIM_GRADE_TOP_SLEEP`: 1 each
  - `hpa-missing-metrics-server` trap: 1
- Live GRADE round-trip (allow up to 60s for metrics-server first scrape)
  deferred to UAT.

## Sibling files surveyed (no edits)

- `setup.sh` — only seeds Deployment + SA (HPA is candidate-authored).
- `ref-solution.sh` — already writes canonical HPA with `type: Utilization` and
  `averageUtilization: 50`.
- `reset.sh` — namespace delete unchanged.
- `metadata.yaml` — trap list (`hpa-missing-metrics-server`,
  `deployment-missing-requests`, `default-sa-used`) unchanged.
- `question.md` — already prescribes `averageUtilization: 50`.

Single-file blast radius confirmed via `git diff --name-only`.
