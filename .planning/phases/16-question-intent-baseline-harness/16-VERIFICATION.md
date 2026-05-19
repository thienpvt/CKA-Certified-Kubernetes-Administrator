---
phase: 16-question-intent-baseline-harness
status: passed
date: 2026-05-19
must_haves_score: 5/5
plans_completed: [16-01, 16-02, 16-03]
requirements_covered: [BASELINE-01, BASELINE-04, DOC-01]
---

# Phase 16 Verification — Question-Intent Baseline Harness

## Phase Goal Check

> Authors and the audit harness share a single source of truth — every question's `expected-symptom.yaml` faithfully encodes its `question.md` prose, and `cka-sim audit` diffs intent against actual cluster state on a clean kind+Calico cluster. (Re-scoped during /gsd-discuss-phase 16: the 34 expected-symptom.yaml files already ship from Phase 15; this phase delivers the audit-mode tool, the AUTHORING.md guide, and the third audit-only artifact integration.)

## Must-Haves

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `cka-sim audit` subcommand exists with three scopes (all/pack/single) and exit codes 0/1/2 | ✓ | `cka-sim/lib/cmd/audit.sh` 0755; `bash cka-sim/bin/cka-sim audit --help` shows all three scopes; no-cluster invocation exits 2 |
| 2 | Forensic-friendly per-question output: PASS one-liner, FAIL table, Claim source block, aggregate summary | ✓ | `_render_question` in audit.sh: PASS-suppression branch, awk-based 6-col table with verdict glyphs, `_claim_source` extracts ±1 line excerpt from question.md, `─── audit summary ───` footer |
| 3 | `--report path/to.md` markdown writer (atomic mktemp + mv) | ✓ | audit.sh main flow: writes via mktemp + mv, includes timestamp + scope header |
| 4 | Lint refactor preserves byte-identical behaviour pre/post (no-cluster warn-skips exit 0) | ✓ | `bash cka-sim/scripts/lint-question-symptom.sh; echo $?` returns 0 with the warn line |
| 5 | docs/AUTHORING.md ships, surfaced from README + reciprocal SCHEMA link, PROJECT.md 38→34 fix bundled | ✓ | `docs/AUTHORING.md` exists (123 lines, 6 H2 sections); `cka-sim/README.md` Documentation section lists 3 docs; `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` has top-of-file blockquote linking back; `grep -c '38 (questions\|total)' .planning/PROJECT.md` returns 0 |

**Score: 5/5 must-haves verified.**

## Plan-Level Outcomes

| Plan | Status | Files | UAT |
|------|--------|-------|-----|
| 16-01 | ✓ Complete | 2 created (lib/symptom-diff.sh, lib/cmd/audit.sh), 3 modified (lint script, dispatcher, help.sh) | Lint exit 0; audit exit 2; help registers audit; test.sh suite unchanged (78/80 passing) |
| 16-02 | ✓ Complete | 1 created (docs/AUTHORING.md), 3 modified (README.md, EXPECTED-SYMPTOM-SCHEMA.md, PROJECT.md) | AUTHORING.md cross-links resolve; PROJECT.md 38→34 fix complete (0 occurrences) |
| 16-03 | ✓ Complete | 5 cases created under cka-sim/tests/cases/ | Test suite 80→85 cases, 78→83 passing, 2 reds unchanged (BLG-05) |

## Requirements Coverage

| Req | Phase | Plans | Status |
|-----|-------|-------|--------|
| BASELINE-01 | 16 | 16-01, 16-03 | ✓ Closed |
| BASELINE-04 | 16 | 16-02 | ✓ Closed |
| DOC-01 | 16 | 16-02 (folded into BASELINE-04) | ✓ Closed |

5/5 active v1.0.2 reqs mapped to Phase 16 are closed (BASELINE-02 and BASELINE-03 were removed during /gsd-discuss-phase 16 reframing — already shipped via Phase 15's expected-symptom.yaml corpus).

## Test Suite Snapshot

```
✗ 2 of 85 case(s) failed
```

The 2 reds are exactly the pre-existing BLG-05 reds (`storage__02-storageclass-dynamic`, `workloads-scheduling__05-daemonset`) carried from v1.0.1. Phase 17 BLG-05 owns root-causing them. Zero new reds introduced by Phase 16.

`bash cka-sim/scripts/test.sh` returns rc=1 because run.sh propagates the BLG-05 reds; this is unchanged from before Phase 16. Earlier UAT runs that returned rc=0 were piping through `tail`, masking the real exit code.

## Audit-Only Boundary Held

- `cka-sim audit` is NOT wired into `.github/workflows/validate.yml` (verified: `grep -c 'cka-sim audit' .github/workflows/validate.yml` returns 0).
- `cka-sim/scripts/lint-question-symptom.sh` (the CI gate, exit 0 on no-cluster) is invoked by `cka-sim/scripts/test.sh` step 7 — unchanged from before refactor.
- Audit's exit-2-on-no-cluster contract is unit-tested (`tests/cases/audit-cmd-no-cluster-exit2.sh`).

## Deferred to Downstream Phases

| Item | Owner |
|------|-------|
| Live-cluster end-to-end audit run (audit actually executing setup.sh against kind+Calico for all 34 questions, rendering FAIL tables, extracting Claim source excerpts) | Phase 18 forensic re-audit |
| shellcheck verification of new files | GHA `validate.yml` shellcheck job (currently red per BLG-06; orthogonal to Phase 16) |
| Manual prose-fidelity audit of all 34 expected-symptom.yaml files (D-07) | Phase 18 (manual side-by-side review) |

## Verification Verdict

**PASSED.** All 5 must-haves verified, all 3 plans landed cleanly, all 5/5 active phase requirements closed, no regression introduced (test suite delta: +5 cases, all passing; pre-existing BLG-05 reds unchanged).

Phase 16 ships the audit subcommand and authoring guide as designed. Ready to advance to Phase 17.
