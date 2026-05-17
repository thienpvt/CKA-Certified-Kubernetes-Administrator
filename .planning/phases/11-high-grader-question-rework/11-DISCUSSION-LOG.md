# Phase 11 Discussion Log

**Discussed:** 2026-05-17
**Mode:** Autonomous --interactive

## Areas Discussed

### BUG-H05 troubleshooting/04-debug-node fix path
- Options presented:
  1. Loosen question; grade only answer.txt (Recommended)
  2. Widen evidence: annotation + image + hostPID
  3. Rewrite ref-solution to use kubectl debug node proper
- **User selection:** Option 1 — Loosen question; grade only answer.txt
- Notes: honest about what's automatable in CI (the label is forgeable; no automated check distinguishes `kubectl debug node` from a hand-rolled privileged pod producing the same artifact). Trap detectors stay as advisory.

### BUG-H06 troubleshooting/05-static-pod-manifest fix path
- Options presented:
  1. Rewrite question framing as YAML repair (Recommended)
  2. Expand grader to test live static-pod semantics
- **User selection:** Option 1 — Rewrite question framing as YAML repair
- Notes: smallest change; preserves existing setup/grader/ref-solution; aligns title with body's actual content (the body already says "Repair sandbox manifest").

## Deferred Ideas

None raised — all stayed in scope.

## Claude's Discretion

- Exact question.md wording for BUG-H05 loosened constraint and BUG-H06 retitled lead paragraph deferred to executor.
- Whether to combine into one plan or split into two — deferred to planner.
