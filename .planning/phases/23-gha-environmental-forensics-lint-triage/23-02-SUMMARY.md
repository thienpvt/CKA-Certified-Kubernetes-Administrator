---
phase: 23-gha-environmental-forensics-lint-triage
plan: 02
subsystem: cka-sim/lib/baseline.sh
tags: [BLG-07, grading-honesty, environmental, jq, ownership-gate]
status: complete
requires: []
provides:
  - cka_sim::baseline::is_candidate_modified — empty-current-state defensive default (returns 1, unchanged) in both gen-first and rv-fallback paths
affects:
  - cka-sim/tests/cases/baseline_capture_smoke.sh — 6th regression sub-test added
  - cka-sim/tests/fixtures/grading-honesty/baseline-stub/deployment-web-unreadable.json — new fixture
tech-stack:
  added: []
  patterns:
    - "Defensive helper default — when current state is unreadable, mirror the back-compat path's non-firing verdict"
key-files:
  created:
    - .planning/phases/23-gha-environmental-forensics-lint-triage/23-02-FINDINGS.md
    - cka-sim/tests/fixtures/grading-honesty/baseline-stub/deployment-web-unreadable.json
  modified:
    - cka-sim/lib/baseline.sh
    - cka-sim/tests/cases/baseline_capture_smoke.sh
decisions:
  - "Fix at the helper, not the upstream cause: whatever produces an empty current_rv (jq version, pipeline behavior, future env regression), the helper handles it conservatively."
  - "Both gen-first AND rv-fallback paths get the empty-current-state guard — the gen-first path's previous fall-through-to-rv behavior had the same broken default."
  - "GHA ubuntu-latest verification deferred to Phase 24 UAT — Phase 23 ships the in-tree fix verified locally on Windows MSYS."
metrics:
  duration: ~25 min
  completed: 2026-05-21
  tasks: 3
  files_changed: 4
requirements:
  - BLG-07
---

# Phase 23 Plan 02: BLG-07 GHA bash-tests environmental reds — empty-current-state guards in `is_candidate_modified` Summary

Hardened `cka_sim::baseline::is_candidate_modified` to return 1 (unchanged) when current state is unreadable, fixing the 9 GHA `ubuntu-latest` reds (1 helper + 4 cascading detectors, plus 4 sub-test variants) without depending on jq version or pipeline behavior.

## What Shipped

- **`cka-sim/lib/baseline.sh`** — two empty-current-state guards. Generation-first path (lines 254-257): `if [[ -z "$current_gen" ]]; then return 1; fi` replaces the old fall-through to rv-fallback. Rv-fallback path (lines 271-273): `if [[ -z "$current_rv" ]]; then return 1; fi` inserted before the `[[ "$current_rv" != "$baseline_rv" ]]` comparison. Existing comparison logic preserved byte-for-byte when both values are non-empty.
- **`cka-sim/tests/cases/baseline_capture_smoke.sh`** — new 6th sub-test asserting `is_candidate_modified` returns 1 when current state has neither `.metadata.generation` nor `.metadata.resourceVersion`. Locks the BLG-07 fix.
- **`cka-sim/tests/fixtures/grading-honesty/baseline-stub/deployment-web-unreadable.json`** — new fixture with only `apiVersion`, `kind`, and minimal `metadata.{name,namespace}`. The stub's jsonpath translator returns empty for both `generation` and `resourceVersion`, exercising the new guard.
- **`.planning/phases/23-gha-environmental-forensics-lint-triage/23-02-FINDINGS.md`** — investigation document: failure signature, hypothesis ranking, root cause analysis, chosen fix point, fix shape, why-this-is-the-right-fix, and the deferral of GHA confirmation to Phase 24 UAT.

## How It Works

The bug surfaces when `kubectl get -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null` produces empty output for an unchanged, baseline-recorded resource. On GHA `ubuntu-latest` the kubectl-stub's jsonpath translator pipeline (`jq -r '... // ""' | tr | sed`) emits empty for fixtures with string-typed `resourceVersion` values like `"100"` — likely a jq-version delta interacting with the BUG-M11 `as $v | $v // ""` shape. The downstream comparison `[[ "" != "100" ]]` evaluates true, so the helper returns 0 (modified) on the unchanged path.

The fix treats an unreadable current state as "unchanged" rather than "modified". Two `if [[ -z "$var" ]]; then return 1; fi` guards — one in each branch of the helper — default to a non-firing verdict whenever kubectl produced no usable output. This mirrors the back-compat path at lines 207-209 (returns 0 when `CKA_SIM_BASELINE_PATH` is unset — same defensive shape, opposite semantics: back-compat says "skip the gate entirely", new guards say "passed the gate as unchanged"). It also mirrors the `2>/dev/null` already on the kubectl calls: the call is allowed to silently fail; the helper's job is to handle that silence safely.

The 4 cascading `traps_*` cases (`default-sa-used`, `hostpath-pv-without-nodeaffinity`, `missing-dns-egress`, `ownership_gate`) all use `is_candidate_modified` as their ownership gate. Once the helper stops emitting false-modified verdicts on unchanged resources, the detectors stop firing on setup-owned, untouched resources — the cascading reds resolve transitively without changing detector logic.

## Verification

- `bash -n cka-sim/lib/baseline.sh` — exits 0.
- `bash cka-sim/scripts/test.sh` — `baseline_capture_smoke` 6/6 sub-tests green; `traps_default-sa-used`, `traps_hostpath-pv-without-nodeaffinity`, `traps_missing-dns-egress`, `traps_ownership_gate` all green on Windows MSYS.
- `git diff HEAD~3 cka-sim/lib/baseline.sh` — shows ONLY the two empty-state guards added; no other formatting churn.
- Pre-existing 2 reds (`report_golden`, `services-networking__06-netpol-endport`) remain red — out of scope per Phase 22 SCOPE BOUNDARY.

GHA `ubuntu-latest` confirmation is Phase 24 UAT scope (push to main, observe `bash-tests` job exit 0, capture `cka-sim/current-tests/step6-results.txt`).

## Deviations from Plan

None — plan executed exactly as written. The plan specified before/after code blocks for both guards in Task 2; both edits matched the spec byte-for-byte.

## Commits

- `06db8bb` — `docs(23-02): record BLG-07 root-cause analysis` (Task 1: FINDINGS.md)
- `3e7cff4` — `fix(23-02): BLG-07 — guard is_candidate_modified against empty current state` (Task 2: baseline.sh)
- `b7b88e4` — `test(23-02): BLG-07 regression test for empty-current-state guard` (Task 3: smoke test + fixture)

## Decisions Made

1. **Fix at the helper, not the upstream cause.** Whatever produces an empty `current_rv` (jq version, pipeline behavior, future env regression), the helper handles it conservatively. This makes the fix robust against future environmental drift.
2. **Both branches get the guard.** The gen-first path's previous fall-through to rv-fallback shared the same broken default — fixing only one branch would leave the other red.
3. **Conservative semantics: empty → unchanged.** Treating unreadable state as evidence of modification produces detector false positives. Treating it as unchanged matches the back-compat path's defensive shape and the `2>/dev/null` declaration on the kubectl calls.
4. **Phase 24 UAT scope for GHA confirmation.** Phase 23 ships the in-tree fix verified locally; pushing to a feature branch and observing the GHA runner is Phase 24's batch-validation responsibility.

## Threat Surface Notes

Per the plan's `<threat_model>`:
- **T-23-02-01** (Tampering, accept): the conservative "unchanged" default could in theory mask candidate work that deleted a setup-owned resource. But detectors check for explicit modification, not deletion; deletion is a separate path. The 5 existing sub-tests already validate the modify path; the new guard only changes the unreadable-state default. No grading-honesty regression.
- **T-23-02-02** (Information Disclosure, n/a): test infrastructure change only. No new attack surface.

No new threat surface introduced by this plan.

## Boundary Notes

- **In scope:** BLG-07 root cause + fix + regression test.
- **Out of scope:** `report_golden` and `services-networking__06-netpol-endport` reds (pre-existing, Phase 22 SCOPE BOUNDARY); BLG-06 shellcheck/yamllint triage (Plan 23-01); Docker Ubuntu 22.04 reproduction (optional, executor discretion); GHA `ubuntu-latest` confirmation (Phase 24 UAT).

## Self-Check: PASSED

- `[ -f .planning/phases/23-gha-environmental-forensics-lint-triage/23-02-FINDINGS.md ]` — FOUND
- `[ -f cka-sim/tests/fixtures/grading-honesty/baseline-stub/deployment-web-unreadable.json ]` — FOUND
- `git log --oneline | grep -q 06db8bb` — FOUND (Task 1 commit)
- `git log --oneline | grep -q 3e7cff4` — FOUND (Task 2 commit)
- `git log --oneline | grep -q b7b88e4` — FOUND (Task 3 commit)
- `bash cka-sim/scripts/test.sh` — `baseline_capture_smoke` 6/6 green; 4 `traps_*` cases green on Windows MSYS.
