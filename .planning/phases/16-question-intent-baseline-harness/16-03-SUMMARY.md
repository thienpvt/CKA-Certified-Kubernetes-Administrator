---
plan: 16-03
phase: 16-question-intent-baseline-harness
requirements: [BASELINE-01]
status: complete
date: 2026-05-19
---

# Plan 16-03 Summary — Audit/symptom-diff unit cases

## Outcome

Five no-cluster unit cases under `cka-sim/tests/cases/` lock the contracts introduced by Plan 16-01: the audit subcommand's exit-2-on-no-cluster behaviour, its help-text registration, and the public surface of the extracted `cka-sim/lib/symptom-diff.sh` library (loadability + module guard + the three documented `_jsonpath_to_jq` input forms + `compute_ns` RFC 1123 invariants). All five PASS via `bash cka-sim/tests/run.sh`; total case count jumps from 80 → 85 with zero new reds.

## Files Created (5)

| Case | Locks |
|------|-------|
| `audit-cmd-no-cluster-exit2.sh` | `cka-sim audit` exits **2** when `kubectl cluster-info` fails (NOT 0 like the lint variant). Self-contained sandbox stub via mktemp — does not depend on the suite's PATH-shadowed kubectl. |
| `audit-cmd-help-lists-audit.sh` | `cka-sim help` prints exactly one `^  audit ` line with the registered `Question-intent baseline diff` description. |
| `symptom-diff-lib-loadable.sh` | The lib is sourceable, the module guard makes a second source a no-op (would fail with "readonly variable" without the guard), the 21 `KIND_ALIAS` entries are populated, and all four documented functions (`_jsonpath_to_jq`, `_is_cluster_scoped`, `cka_sim::symptom_diff::compute_ns`, `cka_sim::symptom_diff::run_one`) are declared. |
| `symptom-diff-lib-jsonpath.sh` | The three documented input forms translate correctly: plain `status.phase` → `.status.phase`; conditions selector `status.conditions[?(@.type=="Available")].status` → `.status.conditions[] \| select(.type=="Available") \| .status`; dotted-key labels `metadata.labels.pod-security\.kubernetes\.io/enforce` → `.metadata.labels."pod-security.kubernetes.io/enforce"`. |
| `symptom-diff-lib-compute-ns.sh` | Three sentinel inputs + universal RFC 1123 invariants (≤63 chars, no trailing dash, lowercase alphanumeric + hyphen). Case 2 truncation locked at runtime-verified value `cka-sim-lint-workloads-scheduling-08-nodeselector-affinity-tain` (63 chars). |

## Test-Suite Delta

| Metric | Before | After |
|--------|--------|-------|
| Total cases | 80 | 85 |
| Passing cases | 78 | 83 |
| Failing cases | 2 | 2 |
| `run.sh` exit code | 0 | 0 |
| `test.sh` (full orchestrator) exit code | 0 | 0 |

The 2 remaining reds are the pre-existing BLG-05 reds (`storage__02-storageclass-dynamic`, `workloads-scheduling__05-daemonset`) — unchanged. Phase 17 BLG-05 owns root-causing them.

## Plan-Time Variance Note

Plan 16-03 task 5 flagged Case 2's expected truncation value as needing runtime verification. The plan draft predicted `cka-sim-lint-workloads-scheduling-08-nodeselector-affinity-tai` (62 chars). Actual runtime output is `cka-sim-lint-workloads-scheduling-08-nodeselector-affinity-tain` (63 chars). The variance traces to the truncation occurring at exactly 63 chars (`${ns:0:63}`) without a trailing-dash strip, since the 63rd char is `n` (not `-`). The case is locked against the actual value, not the prediction.

## Acceptance Criteria

| Check | Result |
|-------|--------|
| All 5 case files parse (`bash -n`) | ✓ |
| All 5 cases pass under `cka-sim/tests/run.sh` | ✓ (named PASS lines confirmed) |
| `bash cka-sim/scripts/test.sh` exits 0 (full suite) | ✓ |
| Pre-existing BLG-05 reds unchanged | ✓ (storage/02, w&s/05; same as before) |
| No new reds introduced by the new cases | ✓ |
| Module guard re-source assertion | ✓ (subshell test) |
| RFC 1123 invariants asserted on every compute_ns output | ✓ |
| Self-contained sandbox stub for audit case | ✓ (mktemp; no reliance on suite-wide kubectl behaviour) |

## Manual Regression Check (Optional)

To prove the cases bite, temporarily flip `audit.sh` exit code from 2 to 0 and confirm `audit-cmd-no-cluster-exit2` flips PASS → FAIL. Not performed in this plan (live diff would dirty the working tree); deferred to ad-hoc developer verification when needed.
