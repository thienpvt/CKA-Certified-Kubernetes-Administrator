---
phase: 19.2-bug-h08-audit-policy-fixture-drift
status: passed
date: 2026-05-20
requirements_covered: [BUG-H08]
closed_by: <pending commit>
---

# Phase 19.2 Verification — BUG-H08 audit-policy grader vs fixture drift

## Outcome

Reconciled `cka-sim/tests/grading-honesty/cluster-architecture__05-audit-policy.sh` with the grader's 4-assertion shape (Phase 13 BUG-M05). The case-file's `expected_setup_score=SCORE: 0/1` and `expected_ref_score=SCORE: 1/1` were stale relative to the grader's 4 weight=1 assertions (secrets@Metadata, configmaps@Request, events@None, omitStages contains RequestReceived).

Two fixes:
1. Updated `expected_setup_score` and `expected_ref_score` to `SCORE: 0/4` and `SCORE: 4/4` matching the grader's actual total.
2. Expanded the ref-solution policy.yaml fixture to cover all 4 grader assertions (was only covering secrets+omitStages → 2/4 score).

## Files Modified (1)

| File | Change |
|------|--------|
| `cka-sim/tests/grading-honesty/cluster-architecture__05-audit-policy.sh` | Updated expected scores to 0/4 + 4/4; expanded ref-solution policy.yaml fixture to cover configmaps@Request and events@None rules. |

## Verification

| Check | Result |
|-------|--------|
| `bash cka-sim/scripts/test.sh` on Linux Docker (Ubuntu 22.04) | ✓ All 88 cases pass, exit 0 |
| Empty submission: `SCORE: 0/4 [audit-escape: setup-state demoted to weight=0]` | ✓ |
| Ref-solution: `SCORE: 4/4` | ✓ |

## BUG-H08 Closed

FORENSIC-v102.md row updated to closed.
