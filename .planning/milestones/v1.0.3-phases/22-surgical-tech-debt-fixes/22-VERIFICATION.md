---
phase: 22-surgical-tech-debt-fixes
verified: 2026-05-21T01:19:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
deferred:
  - truth: "Lab-cluster smoke verification: cka-sim drill <pack> <n> against v1.0.1 cluster shows zero literal ${CKA_SIM_LAB_NS} in candidate-visible prompts across the 20+ affected questions"
    addressed_in: "Phase 24"
    evidence: "Phase 24 goal: 'Every v1.0.3 fix is re-verified on the v1.0.1 lab cluster via a milestone UAT driver' (ROADMAP.md:209)"
  - truth: "Lab-cluster audit verification: cka-sim audit workloads-scheduling/06-static-pod emits SKIPPED row, audit summary advances 33/34 PASS + 1 ERROR -> 33/34 PASS + 1 SKIP"
    addressed_in: "Phase 24"
    evidence: "Phase 24 goal — milestone UAT batch re-verifies on v1.0.1 lab cluster (ROADMAP.md:209); explicitly called out by 22-03-SUMMARY.md 'Pointer to Phase 24 UAT'"
  - truth: "End-to-end LINT-01 lab verification: symptom-diff-regression.sh exits non-zero with 'expected Bound, got Pending' against a live cluster with mutated expected-symptom.yaml"
    addressed_in: "Phase 24"
    evidence: "Phase 24 lab UAT batch is the established v1.0.1/v1.0.2 close-out pattern; case file lines 22-25 self-skip on hosts without live cluster (22-02-SUMMARY.md Verification section)"
  - truth: "Pre-existing red unit cases (report_golden, services-networking__06-netpol-endport) returning to green"
    addressed_in: "Phase 23"
    evidence: "Phase 23 success criterion 3: 'bash cka-sim/scripts/test.sh returns 0 on GHA ubuntu-latest, ...' (ROADMAP.md:204); BLG-06/BLG-07 v1.0.3 backlog scope per CONTEXT.md domain section"
---

# Phase 22: Surgical Tech-Debt Fixes — Verification Report

**Phase Goal:** Three independent, single-point bug fixes land — drill-mode renders namespace-substituted prompts, workloads-scheduling/06-static-pod setup either succeeds on the lab cluster or is documented as unsupported, and the symptom-diff regression test fails as designed when its expected-symptom.yaml is mutated.

**Verified:** 2026-05-21T01:19:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (must-haves from user-supplied verification spec)

| #  | Truth | Status | Evidence |
| -- | ----- | ------ | -------- |
| 1 | DRILL-NS-01: drill.sh contains the parameter-expansion idiom mirroring exam.sh:191-196; new test case `drill_namespace_render.sh` exists and passes | VERIFIED | `cka-sim/lib/cmd/drill.sh:328` literal source bytes: `printf '%s\n' "${question_content//\$\{CKA_SIM_LAB_NS\}/$CKA_SIM_LAB_NS}"`. Mirrors `cka-sim/lib/cmd/exam.sh:196` byte-for-byte (same parameter-expansion form). Standalone run of `cka-sim/tests/cases/drill_namespace_render.sh` exits rc=0 (Tests 1a/1b/2a/2b/2c/3 all green). |
| 2 | AUDIT-W&S06: metadata.yaml carries `unsupported-in-audit-mode: true`; `symptom-diff.sh` honors the flag at the audit entry point; drill/exam paths untouched | VERIFIED | `cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml:8` contains `unsupported-in-audit-mode: true`. `cka-sim/lib/symptom-diff.sh:85-90` defines `cka_sim::symptom_diff::is_unsupported_in_audit_mode` helper (anchored grep on `^unsupported-in-audit-mode:[[:space:]]*true...`). Skip gate wired in `cka-sim/lib/cmd/audit.sh:253-258` (info + `_AUDIT_SKIPPED++` + buffer append + `continue`). Parallel gate in `cka-sim/scripts/lint-question-symptom.sh:60-63`. Drill/exam runners unchanged (verified by absence of `is_unsupported_in_audit_mode` reference in either file). |
| 3 | LINT-01: `_emit_row` uses fd-3 probe (`[[ -e /dev/fd/3 ]]`) before printf; new test case `symptom-diff-emit-row-fd-safe.sh` exists and passes | VERIFIED | `cka-sim/lib/symptom-diff.sh:107-110` body: `_emit_row() { [[ -e /dev/fd/3 ]] || return 0; printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >&3; }`. Format string and arg count preserved (7 TSV cols). Standalone run of `cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh` exits rc=0 (Tests 1/2/3 — lint-mode safety, audit-mode preservation, idempotency — all green). |
| 4 | All 3 REQ-IDs appear in their respective plan SUMMARY's requirements field | VERIFIED | `22-01-SUMMARY.md` frontmatter `requirements: [DRILL-NS-01]`. `22-02-SUMMARY.md` frontmatter `requirements-completed: [LINT-01]`. `22-03-SUMMARY.md` frontmatter `requirements-completed: [AUDIT-W&S06]`. All 3 REQs from REQUIREMENTS.md:12,21,22 covered exactly once. |
| 5 | `bash cka-sim/scripts/test.sh` rc=0 across the new test cases; suite at 89/91 with 2 documented pre-existing reds | VERIFIED | Full suite run: `✗ 2 of 91 case(s) failed`. Failing cases: `report_golden` and `services-networking__06-netpol-endport` — both pre-existing, both documented out-of-scope per phase 22 SCOPE BOUNDARY (22-01-SUMMARY.md:99-106, 22-02-SUMMARY.md:111, 22-03-SUMMARY.md:84). All 3 NEW cases (`drill_namespace_render`, `symptom-diff-emit-row-fd-safe`, `symptom-diff-unsupported-in-audit`) green. Net delta: +3 new green, 0 new reds attributable to this phase, 88 → 91 total (89 green / 2 red). |

**Score:** 5/5 truths verified

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases (per user prompt's explicit deferral to Phase 24 UAT batch).

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Lab-cluster drill-mode smoke (no literal `${CKA_SIM_LAB_NS}` in 20+ candidate-visible prompts) | Phase 24 | Phase 24 goal: re-verify every v1.0.3 fix on v1.0.1 lab cluster |
| 2 | Lab-cluster audit run emits SKIPPED for W&S06 (33/34 PASS + 1 ERROR → 33/34 + 1 SKIP) | Phase 24 | 22-03-SUMMARY.md "Pointer to Phase 24 UAT" |
| 3 | End-to-end `symptom-diff-regression.sh` exits non-zero with `expected 'Bound', got 'Pending'` against live cluster | Phase 24 | 22-02-SUMMARY.md verification section "Deferred to Phase 24 lab UAT" |
| 4 | Pre-existing reds (`report_golden`, `services-networking__06-netpol-endport`) green | Phase 23 | Phase 23 SC#3: full suite returns 0 across env matrix; BLG-06/BLG-07 |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `cka-sim/lib/cmd/drill.sh` | parameter-expansion idiom at ~line 321 | VERIFIED (substantive + wired) | Idiom present at line 328 (in renderer step 3/4 prompt block, lines 320-329). Read by drill runner; exercised by `cka-sim drill <pack> <n>` flow. |
| `cka-sim/tests/cases/drill_namespace_render.sh` | new unit test, 3 sub-tests | VERIFIED | 106 lines, 6 assertions across 3 sections (substitution, selectivity, source-shape lock). Discovered by `cka-sim/tests/run.sh` glob; executed in full suite run. |
| `cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml` | `unsupported-in-audit-mode: true` flag | VERIFIED | Line 8: `unsupported-in-audit-mode: true`. Independent of pre-existing `unsupported-on-kind: true` (line 6). |
| `cka-sim/lib/symptom-diff.sh` (helper) | `is_unsupported_in_audit_mode` function mirroring `is_unsupported_on_kind` | VERIFIED (substantive + wired) | Defined at lines 85-90; called from `audit.sh:253` and `lint-question-symptom.sh:60`. |
| `cka-sim/lib/cmd/audit.sh` (skip gate) | per-question skip gate honoring new flag | VERIFIED | Lines 253-258: info log, `_AUDIT_SKIPPED++`, buffer append, `continue`. Mirrors kind-skip gate immediately above. |
| `cka-sim/scripts/lint-question-symptom.sh` (skip gate) | parallel skip gate | VERIFIED | Lines 60-63: warn + continue. |
| `cka-sim/lib/symptom-diff.sh` (`_emit_row`) | fd-3 probe before printf | VERIFIED (substantive + wired) | Lines 107-110: `[[ -e /dev/fd/3 ]] || return 0` then printf. Called from 8+ sites in `run_one`. |
| `cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh` | new unit test, 3 sub-tests | VERIFIED | 94 lines, 3 sub-tests (fd-closed safety, fd-open TSV byte-identity, repeat-call idempotency). |
| `cka-sim/tests/cases/symptom-diff-unsupported-in-audit.sh` | new unit test for AUDIT-W&S06 helper | VERIFIED | 71 lines, 5 cases (true/missing/false/no-meta/real-pack-walk). Standalone rc=0. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `drill.sh` (renderer) | `question.md` content | parameter-expansion `${question_content//\$\{CKA_SIM_LAB_NS\}/$CKA_SIM_LAB_NS}` | WIRED | Single-line idiom at drill.sh:328 substitutes resolved namespace inline. |
| `audit.sh` (loop) | `is_unsupported_in_audit_mode` | direct function call line 253 | WIRED | Skip gate emits SKIPPED row + increments counter + `continue`. |
| `lint-question-symptom.sh` (loop) | `is_unsupported_in_audit_mode` | direct function call line 60 | WIRED | Warn + continue gate. |
| `_emit_row` callers (8+ in `run_one`) | `_emit_row` function | function call (no caller changes) | WIRED | Function name + signature preserved; printf format byte-identical; audit-mode TSV invariant upheld. |
| `cka-sim/tests/run.sh` | new test cases | filename glob discovery | WIRED | All 3 new cases discovered + executed in full suite run (test count 88 → 91). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| New drill-render test case rc=0 | `bash cka-sim/tests/cases/drill_namespace_render.sh` | rc=0; 6/6 assertions green | PASS |
| New emit-row-fd-safe test case rc=0 | `bash cka-sim/tests/cases/symptom-diff-emit-row-fd-safe.sh` | rc=0; 3/3 sub-tests green | PASS |
| New unsupported-in-audit test case rc=0 | `bash cka-sim/tests/cases/symptom-diff-unsupported-in-audit.sh` | rc=0; 5/5 cases green | PASS |
| Full suite advances by exactly +1 net green from pre-22 baseline | `bash cka-sim/scripts/test.sh` | `✗ 2 of 91 case(s) failed` (was 2/88 pre-phase, +3 new cases all green; same 2 pre-existing reds remain) | PASS |
| Drill-mode source-shape lock matches exam.sh canonical reference | `grep -cF 'question_content//\$\{CKA_SIM_LAB_NS\}/' cka-sim/lib/cmd/drill.sh` | 1 | PASS |
| `_emit_row` fd-probe present in non-comment line | `grep -n '/dev/fd/3' cka-sim/lib/symptom-diff.sh` | line 104 (comment), line 108 (code) | PASS |
| `unsupported-in-audit-mode: true` flag landed on W&S06 only | grep across all metadata.yaml | exactly 1 match (workloads-scheduling/06-static-pod) | PASS |

### Probe Execution

No formal `scripts/*/tests/probe-*.sh` probes are declared by Phase 22 plans; the phase relies on the unit-suite (`cka-sim/scripts/test.sh`) as its in-tree verification driver. The unit suite is exercised in the Behavioral Spot-Checks section above.

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| (n/a — no formal probe declared) | — | — | SKIP (no probe to run) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| DRILL-NS-01 | 22-01-PLAN.md | drill-mode renders `${CKA_SIM_LAB_NS}` substituted prompts; single-point fix at drill.sh:321 | SATISFIED | drill.sh:328 carries the idiom; drill_namespace_render.sh locks the shape; ROADMAP P22 SC#1 met at code-path level (lab smoke deferred to Phase 24) |
| AUDIT-W&S06 | 22-03-PLAN.md | workloads-scheduling/06-static-pod audit deterministic outcome (FIX or SKIP) | SATISFIED | SKIP path chosen with documented evidence; metadata.yaml flag + helper + 2 skip gates wired; ROADMAP P22 SC#2 met at code-path level (lab UAT deferred to Phase 24) |
| LINT-01 | 22-02-PLAN.md | symptom-diff regression-test signal restored via fd-safe `_emit_row` | SATISFIED | fd-3 probe lands; emit-row-fd-safe.sh locks 3 sub-tests; ROADMAP P22 SC#3 met at code-path level (live-cluster end-to-end deferred to Phase 24) |

No orphaned requirements. All three Phase 22 REQ-IDs (REQUIREMENTS.md:12,21,22) appear in plan SUMMARY frontmatter `requirements`/`requirements-completed` fields exactly once.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none) | — | — | — | No `TBD`, `FIXME`, `XXX`, hardcoded empty data, console.log-only handlers, or stub returns introduced by Phase 22 modifications. |

Phase 22 modifications were surgical: (1) 3-line replacement at drill.sh:321 + 5 comment lines; (2) 2-line `_emit_row` body change; (3) 10-line helper add + 2 mirror-pattern skip gates. All changes are minimal, tested, and follow existing established patterns (kind-skip flag shape from Phase 17 BLG-02; exam.sh parameter-expansion shape from quick task `260517-hvo`).

### Human Verification Required

None at the in-tree code level — all five must-haves are programmatically verified via grep/file checks plus the bash unit suite. The four deferred items (lab-cluster smoke, audit SKIP row in lab UAT, end-to-end regression-test exit code, pre-existing red unit cases) are explicitly out of scope for Phase 22 per the phase's SCOPE BOUNDARY contract and are routed to Phase 23 (lint triage) and Phase 24 (lab UAT batch). No additional human steps required to close Phase 22 itself.

### Gaps Summary

No gaps. All five user-supplied must-haves verified at the codebase level. The phase's in-tree code + unit-test deliverables are complete; ROADMAP P22 success criteria 1/2/3/4 are met at the code-path level, with end-to-end lab-cluster verification correctly deferred to Phase 24 per the established v1.0.1/v1.0.2 close-out pattern. The 2 pre-existing red unit cases (`report_golden`, `services-networking__06-netpol-endport`) are documented out-of-scope for Phase 22 in all three plan SUMMARYs and tracked under Phase 23 (BLG-06/BLG-07).

Phase 22 is ready for milestone close-out alongside Phase 23 (parallel-eligible) ahead of Phase 24 v1.0.3 sign-off.

---

_Verified: 2026-05-21T01:19:00Z_
_Verifier: Claude (gsd-verifier)_
