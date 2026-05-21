---
phase: 22-surgical-tech-debt-fixes
plan: 02
subsystem: testing
tags: [bash, fd-redirect, symptom-diff, lint-mode, audit-mode, regression-test]

# Dependency graph
requires:
  - phase: 15-symptom-diff
    provides: "lint-question-symptom.sh + symptom-diff-regression.sh canary"
  - phase: 16-baseline-shared-lib
    provides: "cka-sim/lib/symptom-diff.sh shared lib (BASELINE-01) — sourced by lint and audit"
  - phase: 17-forensic-residuals
    provides: "BLG-02 unsupported-on-kind helper (must remain green post-fix)"
provides:
  - "fd-3-safe _emit_row body — probes /dev/fd/3 before redirecting; lint mode no longer leaks 'Bad file descriptor' to stderr"
  - "Unit test cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh that locks the fd-safe behavior with three sub-tests"
  - "End-to-end signal restoration: regression test path can now reach the FAIL emission and exit 1 on mutated YAML (lab-cluster verification deferred to Phase 24)"
affects: [phase-23-residual-lint-triage, phase-24-uat-batch, audit-run-question, lint-question-symptom]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "fd-probe before redirect: `[[ -e /dev/fd/<N> ]] || return 0` short-circuits BEFORE bash evaluates `>&<N>`, sidestepping the redirect-failure stderr leak that `2>/dev/null` cannot catch on the inside of a failing redirect"

key-files:
  created:
    - cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh
  modified:
    - cka-sim/lib/symptom-diff.sh

key-decisions:
  - "Used `[[ -e /dev/fd/3 ]] || return 0` probe instead of an `exec 3>/dev/null` initializer in lint mode — preserves the lint-vs-audit fd-3 separation and avoids global lint-script state changes."
  - "Rejected wrapping `_emit_row` callers in `2>/dev/null` (would also suppress the `err \"...\"` citations the regression test grep'd) and rejected relocating `2>/dev/null` to the outside of the brace group (still leaks because bash evaluates the >&3 redirect at the calling shell)."
  - "Preserved the printf format string `'%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n'` and the seven positional args verbatim — audit-mode TSV output is byte-identical to pre-fix; cka_sim::audit::_render_question needs no changes."

patterns-established:
  - "fd-probe gate: when an emitter writes to a caller-supplied fd that may or may not be open, probe `[[ -e /dev/fd/<N> ]] || return 0` BEFORE the redirect. Putting `2>/dev/null` on either side of the redirect cannot suppress the bash 'Bad file descriptor' message, because bash emits it at the calling shell level when evaluating the redirect chain."

requirements-completed: [LINT-01]

# Metrics
duration: ~12min
completed: 2026-05-21
---

# Phase 22 Plan 02: LINT-01 _emit_row fd-3 fix Summary

**fd-3-safe _emit_row in cka-sim/lib/symptom-diff.sh — probes `/dev/fd/3` before redirecting so lint mode no longer leaks 'Bad file descriptor' to stderr, restoring the symptom-diff regression-test signal**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-21T00:42:00Z
- **Completed:** 2026-05-21T00:54:38Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments
- Locked LINT-01 behavior with three sub-tests in `cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh`: lint-mode safety (no `Bad file descriptor` leak, rc=0), audit-mode preservation (one byte-identical TSV row to fd 3), and idempotency under repeated lint-mode calls (zero stderr bytes total).
- Replaced the buggy `_emit_row` body in `cka-sim/lib/symptom-diff.sh` (lines 91-96) with a two-statement fd-probe shape: `[[ -e /dev/fd/3 ]] || return 0` then the existing printf with `>&3`. Function comment block also updated to reflect the new mechanism.
- Audit-mode invariant preserved by construction: printf format string and arg order unchanged; `cka_sim::audit::_render_question` reads byte-identical TSV input.
- 7/7 symptom-diff-* unit cases green post-fix (incl. the new emit-row-fd-safe case). The 2 remaining reds in `bash cka-sim/scripts/test.sh` (`report_golden`, `services-networking__06-netpol-endport`) are pre-existing and explicitly out of scope per `22-01-SUMMARY.md` lines 103-104.

## Task Commits

1. **Task 1: Failing test for fd-3-safe _emit_row** — `acf4b86` (test: RED)
2. **Task 2: Make _emit_row safe when fd 3 is not open** — `d1b244e` (fix: GREEN)

_Note: Task 1 is the RED gate of the plan-level TDD cycle (`type: tdd`). Task 2 is GREEN. No REFACTOR commit was needed — the new body is already minimal (two statements: probe + printf)._

## Files Created/Modified

- `cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh` (created) — Unit test with three sub-tests locking `_emit_row` fd-safety: (1) fd 3 closed → no `Bad file descriptor` leak, rc=0; (2) fd 3 open → exactly one byte-identical TSV row; (3) three repeated lint-mode calls → zero stderr bytes total. Pre-sources `lib/colors.sh` + `lib/log.sh` + `lib/symptom-diff.sh` per the lib's header-comment contract. Uses `mktemp -d` + EXIT trap for tmp cleanup. Pure bash + filesystem; no kubectl, no live cluster, no python3.
- `cka-sim/lib/symptom-diff.sh` (modified) — `_emit_row` body changed from `{ printf ... ; } >&3 2>/dev/null || true` (1 line) to `[[ -e /dev/fd/3 ]] || return 0 ; printf ... >&3` (2 lines). Leading 3-line comment block updated to document the new mechanism. Function name and call sites unchanged. Net diff: +5 / -3 lines.

## Before / After: `_emit_row` body diff

```diff
 # --- Structured-row emitter (writes to fd 3 if open) ----------------------
-# Quietly drops if fd 3 is not open. Lint mode does not redirect fd 3 so
-# rows go nowhere; audit mode redirects fd 3 to a tmp file for table render.
+# Returns 0 and emits nothing if fd 3 is not open (probed via /dev/fd/3);
+# otherwise writes one TSV row to fd 3. Audit mode redirects fd 3 to a tmp
+# file; lint mode does not redirect fd 3, so the probe short-circuits.
 _emit_row() {
-  { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"; } >&3 2>/dev/null || true
+  [[ -e /dev/fd/3 ]] || return 0
+  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >&3
 }
```

## Decisions Made

- **fd-probe instead of `exec 3>/dev/null` initializer:** The `[[ -e /dev/fd/3 ]]` test is a pure bash builtin — it does not invoke an external process and does not trigger redirect evaluation, because no `>&3` runs when fd 3 is closed. An `exec 3>/dev/null` shim in lint mode would change global lint-script state and risk bleeding into other commands (e.g., kubectl invocations later in `run_one`). The probe is local to `_emit_row` and matches the lint-vs-audit separation the plan calls out as correct.
- **Preserved printf format string and arg order verbatim:** Audit-mode TSV byte-stability is required by the renderer (`cka_sim::audit::_render_question`). Any change to the format string or arg ordering would shift renderer behavior and break the 33/34 PASS + 1 ERROR Phase-24 audit-mode invariant.
- **Did not touch `_emit_row`'s 8+ call sites in `run_one`:** Per plan instruction "Do NOT touch `_emit_row` callers — only fix the function itself." Confirmed by inspection — all `_emit_row ERROR/MISSING/FAIL/PASS ...` calls keep their current arg shapes.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `bash -n cka-sim/lib/symptom-diff.sh` → exit 0 (syntax clean).
- `bash -n cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh` → exit 0 (syntax clean).
- `bash -c 'set -uo pipefail; export CKA_SIM_ROOT=$PWD/cka-sim; ( source cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh )'` → rc=0 post-fix (was rc=1 pre-fix with Tests 1 and 3 RED on `Bad file descriptor` leak).
- `grep -F '/dev/fd/3' cka-sim/lib/symptom-diff.sh | grep -v '^#' | grep -c 'fd/3'` → 1 (probe present in non-comment line).
- `bash cka-sim/scripts/test.sh` → 88/90 cases pass; all 7 `symptom-diff-*` cases pass (`symptom-diff-emit-row-fd-safe`, `symptom-diff-deploy-wait`, `symptom-diff-lib-compute-ns`, `symptom-diff-lib-jsonpath`, `symptom-diff-lib-loadable`, `symptom-diff-lib-name-substitution`, `symptom-diff-regression` self-skips with rc=0 due to no live cluster, `symptom-diff-unsupported-on-kind`).
- Pre-existing reds (`report_golden`, `services-networking__06-netpol-endport`) unchanged — both documented out of scope in `.planning/phases/22-surgical-tech-debt-fixes/22-01-SUMMARY.md` lines 103-104. Pre-fix baseline run had 3 reds (the same 2 + the new emit-row-fd-safe RED); post-fix run has 2 reds (the same 2). Net: −1 red, zero new reds attributable to this plan.
- **Deferred to Phase 24 lab UAT (per plan):** end-to-end exit-code check on a live cluster — `symptom-diff-regression.sh` exits non-zero on mutated YAML AND captured stderr contains `expected 'Bound', got 'Pending'`. This is the explicit ROADMAP P22 success criterion 3. Locally the regression case self-skips with rc=0 via its `kubectl cluster-info` gate (lines 22-25 of the case file), which is the documented behavior for hosts without a live cluster.

## TDD Gate Compliance

The plan declared `type: tdd` (Task 1 + Task 2 form one RED→GREEN cycle for the `_emit_row` feature):

- **RED gate:** `acf4b86 test(22-02): add failing fd-3-safe _emit_row regression test` — written first, fails on Tests 1 and 3 with `Bad file descriptor` capture. RED state confirmed before Task 2 began.
- **GREEN gate:** `d1b244e fix(22-02): make _emit_row safe when fd 3 is not open (LINT-01)` — body fix lands, all 3 sub-tests pass.
- **REFACTOR gate:** Skipped intentionally — the post-GREEN body (probe + printf) is already minimal; no cleanup pass needed.

Both required gates (RED + GREEN) are present in `git log --oneline` in correct order.

## Threat Model Compliance

| Threat ID | Disposition | Status |
|-----------|-------------|--------|
| T-22-02-01 (DoS via repeated `Bad file descriptor`) | mitigate | Mitigated by `[[ -e /dev/fd/3 ]] || return 0` short-circuit before redirect. Verified by Test 1 and Test 3 of the new unit case. |
| T-22-02-02 (Tampering of audit TSV) | accept | Preserved by construction — printf format and arg order unchanged. Verified by Test 2 (byte-identical `diff -q` against expected TSV). Phase 24 audit invariant verification deferred. |
| T-22-02-03 (TSV side-channel via inadvertent fd 3 inheritance) | accept | Out of scope per threat model. No new exposure introduced. |

No new security-relevant surface introduced. No threat flags.

## Issues Encountered

None during execution. One observation: the first full-suite run (`bzln4kzb5`) produced output the harness truncated to the last 80 lines, which masked which two cases were failing. Re-ran with explicit `> /tmp/...` capture and full-output grep — identified `report_golden` and `services-networking__06-netpol-endport` as the two pre-existing reds, both documented out of scope in 22-01-SUMMARY.md.

## Self-Check: PASSED

Verified post-summary:

- File `cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh` — FOUND.
- File `cka-sim/lib/symptom-diff.sh` — FOUND (modified, contains `[[ -e /dev/fd/3 ]]` at line 96).
- Commit `acf4b86` (test RED gate) — FOUND in `git log --oneline -5`.
- Commit `d1b244e` (fix GREEN gate) — FOUND in `git log --oneline -5`.
- Unit-test rc=0 standalone — confirmed.
- Full-suite run shows the new case green and no new reds attributable to this plan — confirmed.

## Next Phase Readiness

- LINT-01 closed. Symptom-diff lint mode no longer emits noise to stderr; the regression test path is unblocked.
- ROADMAP P22 success criterion 3 (regression test exits non-zero on mutated YAML) is unblocked at the code-path level. End-to-end exit-code verification is the Phase 24 lab UAT batch's responsibility.
- No blockers for Phase 22 plan 03 (next surgical fix in this phase) or Phase 23 (residual lint triage).

---
*Phase: 22-surgical-tech-debt-fixes*
*Completed: 2026-05-21*
