# Phase 15 — Live-Cluster Symptom-Diff CI: Verification

**Phase:** 15-live-cluster-symptom-diff-ci
**Status:** human_needed
**Date:** 2026-05-17

## Status rationale

Static gates all pass on the executor's Windows mingw shell. The lint script's
full live run requires a kind cluster which this executor cannot spin up.
Marked `human_needed` because the formal end-to-end proof is the GHA
`symptom-diff` job's first run on the PR opened to merge this phase.

## Plans completed (7/7)

| Plan | Title                                              | Commit    | Status   |
| ---- | -------------------------------------------------- | --------- | -------- |
| 15-01| Engine + schema doc + 2 motivator YAMLs            | bd29f0e   | Complete |
| 15-02| Storage pack expected-symptom YAMLs (5)            | 4c8d49a   | Complete |
| 15-03| Workloads-scheduling pack expected-symptom (8)     | a3155a5   | Complete |
| 15-04| Services-networking pack expected-symptom (6)      | aa4c075   | Complete |
| 15-05| Cluster-architecture pack expected-symptom (8)     | a5c9c88   | Complete |
| 15-06| Troubleshooting pack expected-symptom (5)          | 982b90f   | Complete |
| 15-07| CI wire-up + synthetic regression test             | d75f4bd   | Complete |

## Static gates (all PASS)

- `find cka-sim/packs -name expected-symptom.yaml -type f | wc -l` -> **34** (count gate).
- All 34 YAMLs parse via `python -c 'import yaml; yaml.safe_load(...)'`.
- `bash -n cka-sim/scripts/lint-question-symptom.sh` -> 0.
- `bash -n cka-sim/tests/cases/symptom-diff-regression.sh` -> 0.
- `bash -n cka-sim/scripts/test.sh` -> 0.
- `bash -n cka-sim/tests/run.sh` -> 0.
- `python -c 'import yaml; yaml.safe_load(open(".github/workflows/validate.yml"))'` -> 0; jobs include `symptom-diff` alongside `yamllint`, `bash-tests`, `shellcheck` (4 jobs total).
- All 5 pre-existing lints pass on HEAD (lint-traps, lint-packs, lint-coverage, lint-trap-coverage, lint-deprecated-strings).
- `cka-sim/scripts/lint-question-symptom.sh` (no cluster) -> warn-skip + exit 0.
- `cka-sim/tests/cases/symptom-diff-regression.sh` (no cluster) -> "no live cluster — SKIP" + exit 0.

## test.sh baseline impact

Phase 15 does NOT modify any question.md / setup.sh / grade.sh; the new files
are expected-symptom YAMLs + a lint script + a regression test case + a
workflow update.

`bash cka-sim/scripts/test.sh` reports **6 of 80 case(s) failed** on HEAD —
identical to the documented Phase 15 entry-state baseline (6 pre-existing
failures: 4 from Phases 10/11 + 2 from Phase 13, all live-cluster drill
regressions tracked separately). The case count rose from 79 to 80 because
the new symptom-diff regression case landed; that case warn-skips with rc=0
on no-cluster machines and is NOT among the 6 failing cases.

**Phase 15 introduces zero new test.sh failures.**

## Gates that require a live cluster (deferred)

These run end-to-end during the merge PR's GHA `symptom-diff` job; they
cannot be exercised here:

- The lint script iterates all 34 questions and exits 0 on a clean tree.
- The synthetic regression case mutates storage/01's PVC claim, the lint
  exits 1 with a `expected 'Bound', got 'Pending'` citation, and the trap
  restores the file.
- shellcheck-clean enforcement (the existing `shellcheck` GHA job will lint
  the new `lint-question-symptom.sh` and `symptom-diff-regression.sh`; local
  shellcheck is not available in this Windows mingw env).

## Files changed (commit-level summary)

- `cka-sim/scripts/lint-question-symptom.sh` (new, 0755)
- `cka-sim/scripts/test.sh` (added step 7)
- `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` (new)
- `cka-sim/packs/{5 packs}/{34 questions}/expected-symptom.yaml` (34 new)
- `cka-sim/tests/cases/symptom-diff-regression.sh` (new, 0755)
- `cka-sim/tests/run.sh` (one-line comment)
- `.github/workflows/validate.yml` (new symptom-diff job, 4th total)
- `.planning/phases/15-live-cluster-symptom-diff-ci/15-{01..07}-SUMMARY.md` (7 summaries)

## Recommendation

Open the merge PR and let the GHA `symptom-diff` job perform the first
live-cluster run. If it exits 0 on a clean tree, all 4 ROADMAP success
criteria are met and Phase 15 transitions from `human_needed` to
`Complete`. If any drift surfaces, fix the affected `expected-symptom.yaml`
to match question.md (or fix the question/setup pair if the drift is real)
and reopen.
