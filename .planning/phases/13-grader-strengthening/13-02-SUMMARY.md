---
phase: 13-grader-strengthening
plan: 02
status: complete
requirements: [BUG-M05]
files_modified:
  - cka-sim/packs/cluster-architecture/05-audit-policy/grade.sh
---

# Plan 13-02 Summary — BUG-M05 cluster-architecture/05-audit-policy

## What changed

- **grade.sh** — Full rewrite replacing the single bundled "structure valid"
  weight=1 assertion with **4 weight=1 scoring assertions**:
  - **A**: some rule has `level=Metadata` AND covers `secrets`
  - **B**: some rule has `level=Request` AND covers `configmaps`
  - **C**: some rule has `level=None` AND covers `events`
  - **D**: `omitStages` contains `RequestReceived`
- Each assertion is a python3 yaml heredoc with `assert any(...)` (heredoc exits
  non-zero on AssertionError → bash if-then-else routes to err/fail).
- Defensive `or {}` / `or []` parse pattern handles empty or malformed YAML
  without crashing the grader.
- The 2 weight=0 informational checks (file exists, has >=1 rule) preserved.
- `audit-policy-wrong-stage-verbosity` trap fires once if any of A/B/C/D fails
  (tracked via `audit_any_fail` flag).
- `cka_sim::grade::emit_result` finalizer preserved.

## Scoring shape

| Submission                          | Score | Trap fires?  |
| ----------------------------------- | ----- | ------------ |
| Empty / setup-stub-only (no level)  | 0/4   | yes          |
| Ref-solution                        | 4/4   | no           |
| Flip Secrets→Request                | 3/4   | yes          |
| Empty file (truncated)              | 0/4   | yes          |

## Verification status

- `bash -n grade.sh` exits 0.
- Acceptance greps all positive:
  - Phase 13 BUG-M05 marker: 1
  - Old "audit policy structure valid/invalid" strings: 0 (removed)
  - 4 scoring assertions each appear 2x (ok + pass message): 2,2,2,2
  - TOTAL +1 increments: 4 (one per scoring assertion)
  - TOTAL +0 no-ops: 2 (informational weight=0 checks)
  - Trap detector: 1
  - `audit_any_fail=1` sets: 4 (one per scoring assertion fail-path)
  - `audit_any_fail == 1` check: 1
- Live GRADE round-trip deferred to UAT.

## Sibling files surveyed (no edits)

- `setup.sh` — stub rule with NO `level:` field; new grader correctly fails 0/4.
- `ref-solution.sh` — already canonical (3 rules + omitStages: [RequestReceived]).
- `reset.sh` — `.cka-sim-sentinel`-guarded purge unchanged.
- `metadata.yaml` — trap list unchanged.
- `question.md` — already prescribes the 4 mappings.

Single-file blast radius confirmed via `git diff --name-only`.
