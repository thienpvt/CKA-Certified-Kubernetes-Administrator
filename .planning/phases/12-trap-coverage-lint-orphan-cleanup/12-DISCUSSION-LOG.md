# Phase 12 Discussion Log

**Discussed:** 2026-05-17
**Mode:** Autonomous --interactive

## Areas Discussed

### LINT-01 home
- Options: new script vs extend lint-traps.sh
- **User selection:** New `scripts/lint-trap-coverage.sh`
- Notes: cleaner separation of concerns; lint-traps.sh stays focused on schema/enum/seed; new script focused on cross-file consistency.

### Orphan policy
- Options: trim vs implement vs mixed
- **User selection:** Trim metadata to match grader
- Notes: matches forensic report's recommendation for storage/04 (no durable intent signal for `reclaim-policy-delete-data-loss`); avoids inventing weak detectors.

## Deferred Ideas

- Workloads-scheduling/01,02,03 metadata-orphan nits noted in forensic report as PASS (not in v1.0.1 scope). Future cleanup task.
- Re-rendering the trap catalog itself — out of scope per REQUIREMENTS.md.

## Claude's Discretion

- Exact lint-trap-coverage.sh implementation (parser style, error formatting) deferred to executor.
- CI wire-up location (`bash-tests` job vs new step) deferred to planner — likely added alongside lint-packs / lint-traps in `.github/workflows/validate.yml`.
- Plan splitting (lint script + 3 metadata trims = 1 plan or 4 plans) deferred to planner.
