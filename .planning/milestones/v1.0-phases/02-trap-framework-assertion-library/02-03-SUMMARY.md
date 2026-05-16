---
phase: 02-trap-framework-assertion-library
plan: 03
subsystem: test-harness
tags: [bash, test-harness, kubectl-stub, lint, ci]
requires:
  - cka-sim/lib/log.sh
  - cka-sim/lib/colors.sh
  - cka-sim/lib/traps.sh  # reference-forward, resolves after plan 02-01 merges
provides:
  - cka-sim/tests/bin/kubectl
  - cka-sim/tests/lib/assert.sh
  - cka-sim/tests/run.sh
  - cka-sim/scripts/test.sh
  - cka-sim/scripts/lint-traps.sh
affects:
  - .gitattributes
tech-stack:
  added:
    - bash unit-test harness (pure bash, no bats/shellspec per D-10)
    - PATH-shadow kubectl stub with jq-backed jsonpath translator (D-09)
    - pure-bash YAML catalog lint (D-04)
  patterns:
    - set-options matrix: -uo pipefail on accumulators, -euo pipefail on validators,
      sourceable libs take neither (matches Phase 1 doctor.sh / validate-local.sh split)
    - CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)" idiom from validate-local.sh
    - PATH-shadow via CKA_SIM_ROOT/tests/bin prepended before case sourcing (D-09)
    - fixture addressing: $CKA_SIM_TEST_FIXTURES_DIR/$CKA_SIM_TEST_CURRENT.json
key-files:
  created:
    - cka-sim/tests/bin/kubectl
    - cka-sim/tests/lib/assert.sh
    - cka-sim/tests/run.sh
    - cka-sim/scripts/test.sh
    - cka-sim/scripts/lint-traps.sh
  modified:
    - .gitattributes
decisions:
  - "D-09 concretized: kubectl stub jsonpath translator protected by || true to keep
     set -euo pipefail from aborting on malformed paths (the desired field-not-found
     signal is an empty stdout)"
  - "D-15 concretized: lint-traps.sh catalog-existence gate runs BEFORE sourcing
     lib/traps.sh — scaffold plan exits 0 in Wave 1 before traps.sh exists"
  - "Top-level pure-bash state-machine uses bare 'last=' assignment, not 'local last=',
     because 'local' outside a function crashes under set -e"
metrics:
  tasks_completed: 2
  tasks_planned: 2
  duration_minutes: 15
  completed_date: 2026-05-09
  files_created: 5
  files_modified: 1
  commits: 2
  lines_added: 447
---

# Phase 2 Plan 03: Test Harness Scaffold Summary

Shipped a pure-bash unit-test harness — PATH-shadowed `kubectl` stub, micro-assertion helpers, case-walker runner, orchestrator wrapper, and catalog lint — so plan 02-04 can plug in fixtures and cases without re-inventing any infrastructure.

## Tasks Completed

| Task | Name                                                                   | Commit  | Files                                                                              |
| ---- | ---------------------------------------------------------------------- | ------- | ---------------------------------------------------------------------------------- |
| 1    | kubectl PATH-shadow stub + assert.sh micro-asserts + .gitattributes    | 3117ced | cka-sim/tests/bin/kubectl, cka-sim/tests/lib/assert.sh, .gitattributes             |
| 2    | tests/run.sh + scripts/test.sh + scripts/lint-traps.sh                 | b9091a0 | cka-sim/tests/run.sh, cka-sim/scripts/test.sh, cka-sim/scripts/lint-traps.sh       |

## What Was Built

**`cka-sim/tests/bin/kubectl` (PATH-shadow stub, D-09).** Extensionless executable that shadows the real `kubectl` when `tests/bin/` is prepended to PATH. Dispatches on `get` / `describe` / `auth can-i` / `exec`, reading fixtures from `$CKA_SIM_TEST_FIXTURES_DIR/$CKA_SIM_TEST_CURRENT.json`. The `get -o jsonpath=...` branch translates kubectl jsonpath (`{.spec.serviceAccountName}`, `{.status.conditions[?(@.type=="Ready")].status}`, `{.subsets[*].addresses[*].ip}`) into jq filters via a two-rule sed translator, then the jq pipe is guarded by `|| true` so malformed paths produce empty stdout rather than aborting the stub. `set -euo pipefail`; silent on happy path; errors to stderr with non-zero exit.

**`cka-sim/tests/lib/assert.sh` (micro-asserts).** Four helpers — `expect_eq`, `expect_empty`, `expect_contains`, `expect_match` — each returning 0 on pass / 1 on fail (never `die`). Sourceable lib: no `set -e/-u` at top level, single `: "${CKA_SIM_ROOT:?}"` defensive check, colors guard mirrors `log.sh`.

**`cka-sim/tests/run.sh` (case-walker, D-10).** `set -uo pipefail` (NOT -e) so failing cases accumulate rather than short-circuit. Sets `CKA_SIM_ROOT` from script location, exports `PATH="$CKA_SIM_ROOT/tests/bin:$PATH"` for the stub shadow and `CKA_SIM_TEST_FIXTURES_DIR="$CKA_SIM_ROOT/tests/fixtures"` for the fixture base. Walks `tests/cases/*.sh` via `find -print0 | sort -z`, sources each in a subshell (keeps case state-leaks from poisoning the runner), tracks `total`/`failed`. Empty-cases-dir and missing-cases-dir both warn-and-exit-0 so this scaffold plan closes green before plan 02-04 ships the cases.

**`cka-sim/scripts/test.sh` (orchestrator, D-11).** `set -euo pipefail` linear driver: step 1 `lint-traps.sh`, step 2 `tests/run.sh`. Mirrors Phase 1's `bootstrap.sh` info/ok step pattern but non-interactive.

**`cka-sim/scripts/lint-traps.sh` (catalog lint, D-15).** Pure-bash YAML state-machine walker (no python, no yq, per D-04) that enforces all 7 D-15 rules on `traps/catalog.yaml`:
- 8 required fields per entry (`name`, `description`, `remediation_hint`, `severity`, `domain`, `source`, `references`)
- RFC 1123 id via `cka_sim::trap::is_valid_id` from `lib/traps.sh` (single source of truth for TRIP-07)
- `severity` / `domain` / `source` closed enums
- `references[].kind` closed enum
- path-existence for `kind: concerns-md` and `kind: prior-art-exercise` targets
- seed completeness for the 8 GRADE-05 ids (`pss-error-string-mismatch`, `psp-fictional-pod-label-exemption`, `kubelet-runtime-flag-in-kubeconfig`, `removed-container-runtime-flag`, `hostpath-pv-without-nodeaffinity`, `as-flag-format-wrong`, `default-sa-used`, `missing-dns-egress`)

**`.gitattributes`.** Extended for `cka-sim/tests/bin/*` (the extensionless stub) and `cka-sim/tests/fixtures/**/*.json` (future fixture tree in plan 02-04). Existing `*.sh text eol=lf` entry preserved.

## Verification

End-to-end green in the scaffold-only state (no catalog, no cases — expected in Wave 1):

```
$ bash cka-sim/scripts/test.sh && echo OK
cka-sim test
  step 1: lint trap catalog
trap catalog lint
! catalog not found: ...cka-sim/traps/catalog.yaml — skipping lint (expected during plan 02-03 scaffold verification)
✓ catalog lint passed
  step 2: run bash unit cases
cka-sim bash unit tests
! no test cases found in ...cka-sim/tests/cases — treat as success during scaffold
✓ all unit cases passed
✓ test.sh complete
OK
```

All 5 bash files parse under `bash -n`. All set-options match the matrix from CONTEXT/PATTERNS (run.sh = `-uo pipefail`, test.sh / lint-traps.sh / kubectl stub = `-euo pipefail`, assert.sh = sourceable lib with neither).

Acceptance criterion spot-checks from the plan (all PASS):

| Check | Result |
|-------|--------|
| `grep -v '^[[:space:]]*#' cka-sim/tests/bin/kubectl \| grep -cE '^[[:space:]]*(get\|auth\|exec\|describe)\)'` | 4 |
| `grep -v '^[[:space:]]*#' cka-sim/tests/lib/assert.sh \| grep -cE '^(expect_eq\|expect_empty\|expect_contains\|expect_match)\(\)'` | 4 |
| `grep -E '^set -' cka-sim/tests/lib/assert.sh \| wc -l` | 0 |
| `grep -c 'export PATH="$CKA_SIM_ROOT/tests/bin:$PATH"' cka-sim/tests/run.sh` | 1 |
| `grep -c 'export CKA_SIM_TEST_FIXTURES_DIR=' cka-sim/tests/run.sh` | 1 |
| seed-ids count (filter comments) | 8 |
| top-level `local last=` count | 0 (bare `last=` used instead) |
| `bash cka-sim/scripts/test.sh && echo OK` | OK |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reordered `source lib/traps.sh` below catalog-existence gate in lint-traps.sh**
- **Found during:** Task 2 (Wave 1 parallel constraint — `cka-sim/lib/traps.sh` is authored by plan 02-01, which runs in the same wave and has not merged into this worktree).
- **Issue:** The plan's action block for lint-traps.sh sources `lib/traps.sh` immediately after `lib/colors.sh` / `lib/log.sh`, which is BEFORE the catalog-existence check. In this worktree traps.sh does not exist yet, so `source` would fail hard and the scaffold-only success criterion (`bash cka-sim/scripts/test.sh && echo OK returns OK from the worktree`) could never pass.
- **Fix:** Moved the `source "$CKA_SIM_ROOT/lib/traps.sh"` line below the `if [[ ! -f "$catalog" ]]; then warn ...; exit 0; fi` gate, with an inline comment explaining the Wave-1 deferral. When the catalog is absent we exit 0 before ever touching traps.sh; when the catalog lands (post-02-02) traps.sh is also present (post-02-01) and the validation path runs normally.
- **Files modified:** `cka-sim/scripts/lint-traps.sh`
- **Commit:** b9091a0

**2. [Plan-internal note] `^set -uo pipefail$` acceptance regex vs. inline-comment action**
- **Found during:** Task 2 acceptance check.
- **Issue:** The plan's action block for `tests/run.sh` writes `set -uo pipefail   # NOT -e: ...` with a trailing comment on the same line (load-bearing comment per PATTERNS.md line 85-87). The corresponding acceptance command (`grep -q '^set -uo pipefail$'`) anchors to end-of-line and will not match. The stricter-intent check (`! grep -qE '^set -[a-z]*e[a-z]*o'`) does pass.
- **Decision:** Kept the inline comment verbatim because PATTERNS.md explicitly calls the comment "load-bearing; preserve it". Flagging for planner. Functional behavior (`-uo` present, `-e` absent) is correct.
- **Fix:** None required — this is a cosmetic inconsistency in the acceptance criterion text, not a code defect.

### Other Notes

**jq-dependent kubectl-stub dry-run acceptance:** The plan's Task 1 acceptance includes a dry-run (`CKA_SIM_TEST_FIXTURES_DIR=/tmp/... bash cka-sim/tests/bin/kubectl get pod x -o jsonpath=...`) that requires `jq`. `jq` is not installed on the Windows dev host where this executor runs, so this check was not exercised locally. `bash -n` syntax validation passes, and the CI path (`ubuntu-latest` per D-11) has `jq` pre-installed so the dry-run will run there once plan 02-05 wires the GHA job. Pure syntax check + intent-level grep checks all pass here.

## Open Hooks for Plan 02-04

The harness is now ready to receive content in plan 02-04:

- **24 detector fixtures** (8 detectors × 3 scenarios per D-12): drop JSON files under `cka-sim/tests/fixtures/<trap-id>/{hit,miss,benign}.json`. Case files set `CKA_SIM_TEST_CURRENT=<trap-id>/hit` before calling the detector.
- **~14 assertion-helper fixtures** (7 helpers × happy-path + sad-path): same pattern, e.g. `cka-sim/tests/fixtures/assert_pod_ready/{happy,sad}.json`.
- **8 detector test cases**: `cka-sim/tests/cases/traps_<trap-id>.sh` — source `lib/traps.sh` + `tests/lib/assert.sh`, run three sections (hit/miss/benign) per detector using `expect_eq` / `expect_empty`.
- **7 assertion-helper test cases**: `cka-sim/tests/cases/grade_<helper>.sh` — happy + sad per helper.
- **Catalog content** arrives from plan 02-02 (Wave 2); once present, `lint-traps.sh`'s graceful-skip path drops out and full schema enforcement kicks in.

All five scaffold files need zero modification to accommodate those additions — they were designed to walk tree content that does not yet exist.

## Self-Check

Files created (6):
- FOUND: cka-sim/tests/bin/kubectl
- FOUND: cka-sim/tests/lib/assert.sh
- FOUND: cka-sim/tests/run.sh
- FOUND: cka-sim/scripts/test.sh
- FOUND: cka-sim/scripts/lint-traps.sh
- FOUND: .gitattributes (modified — extended with 2 new entries)

Commits (2):
- FOUND: 3117ced feat(02-03): kubectl stub + assert.sh + .gitattributes
- FOUND: b9091a0 feat(02-03): run.sh + test.sh + lint-traps.sh

## Self-Check: PASSED
