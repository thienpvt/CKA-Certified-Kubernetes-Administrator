---
plan: 17-01
phase: 17-v1-0-2-backlog-cleanup
requirements: [BLG-01]
status: complete
date: 2026-05-19
---

# Plan 17-01 Summary — Pattern A `${CKA_SIM_LAB_NS}` substitution in resource name

## Outcome

Fixed Pattern A (BLG-01) at the single source of truth in `cka-sim/lib/symptom-diff.sh`. The python parser embedded in `cka_sim::symptom_diff::run_one` now substitutes `${CKA_SIM_LAB_NS}` on resource `name` fields (3 lines: R, E, A event types), not just on `namespace` and `expect`-values.

After this plan:
- All 12 Pattern A affected questions (cluster-architecture/{03,04,05,06,07}, services-networking/05, troubleshooting/{04,05,06}, workloads-scheduling/05, plus 2 more identified by grep) compute kubectl get with the substituted namespace name.
- Lint and audit both benefit from the single lib fix — no per-YAML edit, no driver edit.
- A new no-cluster unit case (`cka-sim/tests/cases/symptom-diff-lib-name-substitution.sh`) locks the contract: it constructs a tmp YAML with `name: ${CKA_SIM_LAB_NS}`, drives the parser via the same python heredoc the lib uses, and asserts the substituted ns appears in the parsed output (and the literal placeholder does NOT).

## Files Modified (1) + Created (1)

| File | Change |
|------|--------|
| `cka-sim/lib/symptom-diff.sh` | 3 sub(name) wraps in the python heredoc inside run_one (R, E, A event-type prints). |
| `cka-sim/tests/cases/symptom-diff-lib-name-substitution.sh` | NEW. Reproduces the parser in isolation, asserts substitution on R + E events, asserts no literal placeholder leaks. Skips gracefully on hosts without python3+yaml (Windows MSYS Microsoft Store stub). |

## Test Suite Delta

| Metric | Before | After |
|--------|--------|-------|
| Total cases | 85 | 86 |
| Passing | 83 | 84 |
| Failing | 2 (BLG-05 carry-forwards) | 2 (BLG-05 carry-forwards) |

The new case PASSes cleanly. The 2 reds are the same pre-existing BLG-05 reds; Plan 17-04 closes them.

## Plan-Time Variance Note

The case-file initially crashed on this Windows MSYS host because `python3` resolves to a Microsoft Store stub instead of `/c/Python312/python.exe`. The lib itself sidesteps this because its python heredoc only runs after `lint-question-symptom.sh`'s tool preflight (which dies if python3+yaml is unavailable) and after the cluster-info gate (which warn-skips on no-cluster Windows). The case mirrors the lib's preflight pattern with a graceful skip — `python3 -c 'import yaml' >/dev/null 2>&1 || exit 0` — so the contract is unit-tested on CI Linux while not blocking local Windows runs.

## Acceptance Criteria

| Check | Result |
|-------|--------|
| `grep -c 'sub(name)' cka-sim/lib/symptom-diff.sh` returns 3 | ✓ |
| No `print('[REA]', kind, name,` (non-sub) leaks remain | ✓ |
| All Phase 16 + Plan 17-01 cases PASS via `bash cka-sim/tests/run.sh` | ✓ |
| New case `symptom-diff-lib-name-substitution` PASSes | ✓ |
| Lint exit 0 on no-cluster (regression check) | ✓ |
| Audit exit 2 on no-cluster (regression check) | ✓ |
