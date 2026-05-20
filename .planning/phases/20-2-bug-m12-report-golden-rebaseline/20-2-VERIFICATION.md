---
phase: 20.2-bug-m12-report-golden-rebaseline
status: passed
date: 2026-05-20
requirements_covered: [BUG-M12]
closed_by: <pending commit>
---

# Phase 20.2 Verification — BUG-M12 report_golden re-baseline

## Outcome

Re-baselined `cka-sim/tests/fixtures/exam/expected-report.md` from the live exam-mode renderer running on Linux. Root cause: the previous fixture was checked in with mixed CRLF/CR/LF line endings (Windows checkout state), but `cka-sim/lib/exam-report.sh` emits LF-only output. `diff -u` saw byte-level divergence even though the rendered text was visually identical.

## Files Modified (2)

| File | Change |
|------|--------|
| `cka-sim/tests/fixtures/exam/expected-report.md` | Regenerated from `cka_sim::report::render` on Linux — pure LF, 2548 bytes. Renormalized via `git add --renormalize`. |
| `.gitattributes` | Added `cka-sim/tests/fixtures/**/*.md text eol=lf` rule to prevent future drift on Windows checkouts. |

## Verification

| Check | Result |
|-------|--------|
| `bash cka-sim/scripts/test.sh` on Linux Docker (Ubuntu 22.04) | ✓ All 88 cases pass; `report_golden` Test 1 PASSES |
| Per-domain score table format stable | ✓ |
| Total = 64/100 still computed correctly | ✓ Test 2 PASSES |
| All required sections present | ✓ Test 3 PASSES |

## BUG-M12 Closed

FORENSIC-v102.md row updated to closed.
