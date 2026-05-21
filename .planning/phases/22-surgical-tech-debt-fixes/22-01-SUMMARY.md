---
phase: 22
plan: 01
subsystem: drill-runner
tags: [drill, render, namespace, ux, surgical-tech-debt]
requires:
  - exam.sh:191-196 parameter-expansion shape (canonical reference)
provides:
  - drill-mode renders ${CKA_SIM_LAB_NS} substituted inline in candidate-visible prompts
affects:
  - cka-sim/lib/cmd/drill.sh (single render site)
tech-stack:
  added: []
  patterns:
    - "pure-bash parameter-expansion ${var//\\$\\{TOKEN\\}/$repl} for single-token substitution"
key-files:
  created:
    - cka-sim/tests/cases/drill_namespace_render.sh
  modified:
    - cka-sim/lib/cmd/drill.sh
decisions:
  - Mirror exam.sh:191-196 verbatim — same shape, same comments-style; pure-bash, no envsubst.
  - Only ${CKA_SIM_LAB_NS} is substituted; other ${VAR} or $VAR shapes survive verbatim (per threat T-22-01-01 mitigation).
  - Test scaffold mirrors drill_namespace_construction.sh — sourced (not exec'd) by tests/run.sh, set -uo pipefail, case_failed flag, exit case_failed.
  - Test 3 (source-shape lock) uses grep -F with backslash-escaped braces matching the literal bash parameter-expansion source bytes (`\$\{CKA_SIM_LAB_NS\}`). The PLAN's pattern (`${CKA_SIM_LAB_NS}` without backslashes) does not match either drill.sh or exam.sh — corrected during Task 2 verify as a Rule 1 deviation.
metrics:
  duration: ~14m
  completed: 2026-05-21
requirements:
  - DRILL-NS-01
---

# Phase 22 Plan 01: DRILL-NS-01 — drill-mode envsubst render Summary

Drill mode now renders `question.md` with `${CKA_SIM_LAB_NS}` substituted inline using the same pure-bash parameter-expansion shape exam mode has shipped since quick task `260517-hvo`. Single-line surgical fix at `cka-sim/lib/cmd/drill.sh:321` plus a new locked-shape unit case at `cka-sim/tests/cases/drill_namespace_render.sh`.

## What Changed

### `cka-sim/lib/cmd/drill.sh`

Replaced the single line:

```bash
cat "$CKA_SIM_QUESTION_DIR/question.md"
```

with the read-into-variable + parameter-expansion shape mirroring `cka-sim/lib/cmd/exam.sh:194-196`:

```bash
local question_content
question_content=$(<"$CKA_SIM_QUESTION_DIR/question.md")
printf '%s\n' "${question_content//\$\{CKA_SIM_LAB_NS\}/$CKA_SIM_LAB_NS}"
```

Surrounding lines (`info "step 3/4: prompt"` and `info "Lab ns: $CKA_SIM_LAB_NS"`) are byte-identical to pre-edit. Five lines of comment added above the new logic so future readers see the rationale (mirrors exam.sh comment style).

Net diff: `+8 -1` on drill.sh (3 functional lines + 5 comment lines added; 1 functional line removed).

### `cka-sim/tests/cases/drill_namespace_render.sh` (new)

103-line unit case with three sections under a single `case_failed` flag:

1. Substitution behaviour — given a tmp `question.md` with the literal `${CKA_SIM_LAB_NS}` token and `CKA_SIM_LAB_NS=cka-sim-test-01`, the expansion produces `cka-sim-test-01` and no literal placeholder.
2. Selectivity — `$OTHER_VAR` and `${UNRELATED}` survive verbatim; only the one token we own is replaced (locks threat T-22-01-01 mitigation).
3. Source-shape lock — `grep -qF 'question_content//\$\{CKA_SIM_LAB_NS\}/'` against `cka-sim/lib/cmd/drill.sh` (regression guard against reverting to plain `cat`).

Pure bash; no kubectl, no python3, no live cluster required. Cleans up its tmp dir via `trap '... EXIT'`.

## Tasks

| Task | Status | Commit | Files |
|------|--------|--------|-------|
| 1: Failing test for namespace render shape (TDD RED) | done | `79dcdbe` | `cka-sim/tests/cases/drill_namespace_render.sh` (new, 103 lines) |
| 2: Apply parameter-expansion render at drill.sh:321 (TDD GREEN) | done | `75ed497` | `cka-sim/lib/cmd/drill.sh` (+8/-1), `cka-sim/tests/cases/drill_namespace_render.sh` (Test 3 grep pattern fix) |

## Verification

```text
$ bash cka-sim/tests/cases/drill_namespace_render.sh
  ✓ Test 1a: resolved ns appears in rendered output
  ✓ Test 1b: literal placeholder absent from rendered output
  ✓ Test 2a: target token substituted
  ✓ Test 2b: $OTHER_VAR survived verbatim
  ✓ Test 2c: ${UNRELATED} survived verbatim
  ✓ Test 3: drill.sh carries the parameter-expansion idiom
rc=0

$ bash -n cka-sim/lib/cmd/drill.sh
rc=0

$ grep -cF 'question_content//\$\{CKA_SIM_LAB_NS\}/' cka-sim/lib/cmd/drill.sh
1

$ bash cka-sim/tests/run.sh
... (88 prior cases + 1 new drill_namespace_render case + 1 prior drill_namespace_construction case)
✗ 2 of 90 case(s) failed   ← pre-existing reds, see "Pre-existing Reds" below
```

## Pre-existing Reds (Out of Scope)

The full unit suite reports 2 failing cases. Both are pre-existing reds documented in `cka-sim/current-tests/step1-results.txt:907-908` and unrelated to drill.sh:

- `tests/exam/report_golden.sh` — golden-file drift (no drill.sh references in this case file).
- `tests/grading-honesty/services-networking__06-netpol-endport.sh` — empty-submission scoring delta (`SCORE: 0/4` vs `SCORE: 0/8`; no drill.sh references).

Confirmed via `grep -l 'drill.sh\|cka_sim::drill'` against both files — no match. These are tracked under separate plans (BLG-06/BLG-07 for v1.0.3, per Phase 22 CONTEXT.md `<domain>` boundary).

The plan's `bash cka-sim/scripts/test.sh` acceptance criterion is satisfied: zero NEW reds attributable to this change.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected Test 3 grep pattern to match the canonical source-bytes shape**

- Found during: Task 2 verification (`grep -F 'question_content//${CKA_SIM_LAB_NS}/'` returned no hits even though the fix had landed).
- Issue: The PLAN's grep pattern (`question_content//${CKA_SIM_LAB_NS}/`) does not match either `drill.sh` (post-fix) or `exam.sh:196` (the canonical reference). Both files use the bash parameter-expansion form `\$\{CKA_SIM_LAB_NS\}` with backslash-escaped braces — the literal source bytes required to match the `${VAR}` token in a bash parameter expansion.
- Fix: Changed Test 3 to `grep -qF 'question_content//\$\{CKA_SIM_LAB_NS\}/'`. Validated against `cka-sim/lib/cmd/exam.sh:196` (returns rc=0 — the same shape works for the canonical reference).
- Files modified: `cka-sim/tests/cases/drill_namespace_render.sh`.
- Commit: `75ed497` (folded into Task 2 GREEN commit since the source-shape lock IS Task 2's exit gate).

This is the test-bug shape: the test was written against the PLAN's stated grep pattern which itself was wrong about the source bytes. The fix preserves Test 3's intent (regression guard against reverting to `cat`) while matching the actual idiom shipped in both drill.sh and exam.sh.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None — no new security-relevant surface introduced. Threat register T-22-01-01 (parameter-expansion tampering) and T-22-01-02 (namespace-name disclosure) both addressed/accepted as planned.

## TDD Gate Compliance

- RED gate: `79dcdbe` (`test(22-01): add failing drill_namespace_render case for DRILL-NS-01`) — Test 3 fails with `case_failed=1` because drill.sh:321 still uses `cat`.
- GREEN gate: `75ed497` (`feat(22-01): drill-mode renders ${CKA_SIM_LAB_NS} substituted prompts`) — all three tests pass; idiom appears exactly once in drill.sh.
- REFACTOR gate: not needed — single-line fix; no follow-up cleanup.

Tests 1 and 2 (which validate the bash parameter-expansion language feature itself) passed in the RED state because they exercise pure bash — they ride along as additional locks rather than gating the cycle. Test 3 is the canonical RED→GREEN gate.

## Self-Check: PASSED

- `cka-sim/tests/cases/drill_namespace_render.sh` exists.
- `cka-sim/lib/cmd/drill.sh` modified (verified via `git diff HEAD~2 -- cka-sim/lib/cmd/drill.sh` shows the 3-line replacement at line 321).
- Commit `79dcdbe` exists in `git log --all` (RED gate).
- Commit `75ed497` exists in `git log --all` (GREEN gate).
- Verification: `bash cka-sim/tests/cases/drill_namespace_render.sh` exits 0; `bash -n cka-sim/lib/cmd/drill.sh` exits 0; `grep -cF 'question_content//\$\{CKA_SIM_LAB_NS\}/' cka-sim/lib/cmd/drill.sh` returns 1.
