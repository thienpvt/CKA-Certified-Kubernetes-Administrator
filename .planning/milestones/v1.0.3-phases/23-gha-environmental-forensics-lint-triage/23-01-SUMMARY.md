---
phase: 23
plan: 01
subsystem: lint-config
tags: [BLG-06, shellcheck, yamllint, gha, lint-triage]
requires: [Plan 17-05 continue-on-error scaffolding]
provides: [lint-clean cka-sim corpus, hard CI gate on shellcheck/yamllint regressions]
affects: [.github/workflows/validate.yml, .shellcheckrc (new), cka-sim/scripts/validate-local.sh, 11 source files in cka-sim/]
tech_stack_added: [.shellcheckrc]
patterns: [repo-global lint disable with rationale, per-line shellcheck disable with rationale, fixture-directory lint exclusion]
key_files_created:
  - .shellcheckrc
  - .planning/phases/23-gha-environmental-forensics-lint-triage/23-01-FINDINGS.md
  - .planning/phases/23-gha-environmental-forensics-lint-triage/23-01-SUMMARY.md
key_files_modified:
  - .github/workflows/validate.yml
  - cka-sim/scripts/validate-local.sh
  - cka-sim/lib/cmd/bootstrap.sh
  - cka-sim/lib/cmd/doctor.sh
  - cka-sim/lib/cmd/exam.sh
  - cka-sim/lib/symptom-diff.sh
  - cka-sim/lib/traps.sh
  - cka-sim/packs/cluster-architecture/04-pss-enforce/grade.sh
  - cka-sim/packs/services-networking/05-kube-proxy-mode/grade.sh
  - cka-sim/scripts/uat-phase10.sh
  - cka-sim/scripts/uat-phase13.sh
  - cka-sim/scripts/uat-phase18-21.sh
  - cka-sim/tests/phase7-uat.sh
decisions:
  - "Used Docker Ubuntu 22.04 (Path A) for deterministic shellcheck 0.8.0 + yamllint 1.38.0 reproduction; local Windows host has neither tool"
  - "Repo-global .shellcheckrc disables for SC1091/SC1090/SC2034/SC2016/SC2181/SC2155 — each carries one-line rationale; covers 120 of 153 shellcheck findings"
  - "yamllint line-length max bumped 200 -> 500 in validate-local.sh inline rules; catalog.yaml description fields are deliberately verbose single-line strings (~420 chars worst case)"
  - "Added find -not -path '*/tests/fixtures/exam/packs/*' to validate-local.sh shellcheck pass; mock-pack-alpha graders are intentionally-malformed fixtures testing exam runner behaviour"
  - "Per-line disables (17 total) for SC2088/SC2015/SC2030/SC2031/SC2120/SC2119/SC2086/SC2028/SC2012 — each rationale documented inline above the offending line"
  - "fix-in-code only for SC2002 (4 findings) — mechanical replacement of `cat file | tr` with `tr < file`"
metrics:
  duration_minutes: 90
  tasks_completed: 2
  files_changed: 13
  findings_dispositioned: 196
  completed_date: 2026-05-21
---

# Phase 23 Plan 01: BLG-06 Per-Finding Shellcheck/Yamllint Triage Summary

Walked all 195 shellcheck and yamllint findings emitted by `validate-local.sh` (reproduced under Docker Ubuntu 22.04 with shellcheck 0.8.0 + yamllint 1.38.0), dispositioned each one, applied fixes, and lifted the temporary `continue-on-error: true` scaffolding from `.github/workflows/validate.yml:84` so the GHA `shellcheck` job is now a hard CI gate.

## What Shipped

- `.shellcheckrc` (new repo-global config): six rule disables with one-line rationale per disable (SC1091, SC1090, SC2034, SC2016, SC2181, SC2155). Covers the bulk of "intentional corpus idiom" warnings.
- `cka-sim/scripts/validate-local.sh`: yamllint inline `line-length` max bumped 200 -> 500; shellcheck pass excludes `tests/fixtures/exam/packs/*` (intentionally-malformed grader fixtures).
- 11 source-file edits: 4 fix-in-code (SC2002 cat-pipe rewrite) + 17 per-line disables across 8 files (SC2088, SC2015, SC2030/SC2031, SC2120/SC2119, SC2086, SC2028, SC2012).
- `.github/workflows/validate.yml`: removed `continue-on-error: true` from the `shellcheck` job; preserved the `Print shellcheck findings (BLG-06 triage)` step at line 95 for future PR triage.
- `23-01-FINDINGS.md`: per-finding audit trail (file:line | rule | disposition | mechanism | rationale) for the 195 dispositions, plus reproduction recipe and config-change shopping list.

## Disposition Summary

| Disposition | Count |
|-------------|-------|
| fix-in-code | 4 |
| relax-with-rationale | 179 |
| out-of-scope | 12 |
| **Total** | **195** |

Mechanism breakdown for relax-with-rationale: 162 repo-global (.shellcheckrc + yamllint inline tuning), 17 per-line `# shellcheck disable=`.

## Verification

- `bash cka-sim/scripts/validate-local.sh` (Ubuntu 22.04 container): rc=0 — corpus is lint-clean.
- `python3 yaml.safe_load(.github/workflows/validate.yml)` round-trips ok — YAML structurally valid.
- `grep -c 'continue-on-error: true' .github/workflows/validate.yml` returns 0 — the scaffolding is fully removed.
- `Print shellcheck findings (BLG-06 triage)` step at line 95 byte-identical to its pre-edit form.
- `bash cka-sim/scripts/test.sh`: 2 pre-existing Windows-environment reds (`report_golden` golden-file timestamp diff; `services-networking__06-netpol-endport` scoring expectation). Neither involves files touched by Plan 23-01; verified by stashing edits and re-running. The 9 BLG-07 reds noted in `step1-results.txt` are GHA-Linux-only and remain Plan 23-02's scope.
- GHA confirmation deferred to Phase 24 UAT per CONTEXT.md (push to `main`, observe `validate.yml` shellcheck job exits 0, capture in `cka-sim/current-tests/step6-results.txt`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] doctor.sh:106 SC2088 finding missed in Task 1 extraction**
- **Found during:** Task 2 verification re-run.
- **Issue:** The Task 1 raw-output parser concatenated the SC2088 warning at doctor.sh:106 with the trailing `https://www.shellcheck.net/wiki/SC2088 -- ...` "For more information" link, hiding the second tilde site from the extraction awk. After applying the disposition for line 98, the second hit at line 106 surfaced.
- **Fix:** Added the same per-line `# shellcheck disable=SC2088  # rationale: literal user-facing text, not a path expansion` directly above doctor.sh:106. Same disposition (per-line relax-with-rationale) as line 98.
- **Files modified:** `cka-sim/lib/cmd/doctor.sh`
- **Commit:** `67c79ef`

Total findings dispositioned: 195 in FINDINGS.md + 1 newly-discovered = 196.

## Commits

| Stage | Commit | Message |
|-------|--------|---------|
| Task 1 | `d74d076` | docs(23-01): record BLG-06 disposition table for 195 lint findings |
| Task 2 stage A | `f0067de` | chore(23-01): add .shellcheckrc + relax yamllint line-length + exclude grader fixtures |
| Task 2 fix-in-code | `58d0909` | fix(23-01): replace useless cat with input redirection (SC2002) |
| Task 2 stage B | `67c79ef` | chore(23-01): add per-line shellcheck disables for 18 remaining findings |
| Task 2 final | `0a9e08f` | feat(23-01): lift continue-on-error from shellcheck job (BLG-06 closed) |

## Threat Surface

No new network endpoints, auth paths, or trust-boundary surface introduced. The `.shellcheckrc` global disables widen what slips past shellcheck — all six are documented in the file itself with one-line rationale per disable, and disposition rule ordering (CONTEXT.md BLG-06) was followed (fix-in-code preferred for word-split bug classes; relax reserved for corpus idioms / dynamic-source patterns).

## Self-Check: PASSED

Verified before commit:
- `.planning/phases/23-gha-environmental-forensics-lint-triage/23-01-FINDINGS.md` — FOUND
- `.shellcheckrc` — FOUND
- All 5 commit hashes present in `git log --oneline --all`
- Container re-run of `validate-local.sh` — rc=0
