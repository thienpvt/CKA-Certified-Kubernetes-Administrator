---
phase: 03-runtime-contract-drill-mode
plan: 02
subsystem: runtime
tags: [bash, drill, orchestrator, trap-cleanup, mktemp, yaml-parser, unit-tests]

# Dependency graph
requires:
  - phase: 01-cluster-bootstrap-runner-skeleton
    provides: lib/colors.sh, lib/log.sh, lib/preflight.sh, bin/cka-sim router, ~/.cka-sim state dirs
  - phase: 02-trap-grader-contract
    provides: lib/grade.sh + lib/traps.sh (consumed by per-question grade.sh subprocesses), cka-sim/tests/lib/assert.sh, cka-sim/tests/run.sh + test.sh harness
provides:
  - Full drill orchestrator at cka-sim/lib/cmd/drill.sh (replaces 13-line Phase 1 stub, ~290 LOC, 7 functions)
  - Env-var contract for subprocess scripts — CKA_SIM_PACK_ID, CKA_SIM_QUESTION_ID, CKA_SIM_LAB_NS, CKA_SIM_QUESTION_DIR
  - TRIP-03 lab namespace convention — cka-sim-<pack>-NN with zero-padded NN
  - TRIP-05 orchestration order — reset.sh before setup.sh; EXIT-trap reset on any exit
  - Pure-bash manifest.yaml parser (mirrors lib/traps.sh pattern) for packs/<pack>/manifest.yaml
  - 4 drill unit tests verifying parser, index selection, namespace format, orchestration order (offline, no live cluster)
  - 3 manifest fixtures (storage, multi, empty) for parser tests
affects: 03-03-lint-packs, 03-04-reference-questions, 03-05-mock-exam, 04-exam-mode, every future packs/*/*/grade.sh consumer

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "EXIT-trap lifecycle: trap registered in main() body (never inside the trap function) — Pitfall 2 avoidance"
    - "Report file via mktemp + atomic mv (NOT `| tee`) — Pitfall 1 avoidance against SIGPIPE/partial-write races"
    - "Drill runs grade.sh as a subprocess + captures stdout to tempfile — does NOT source lib/grade.sh or lib/traps.sh — Pitfall 5 avoidance"
    - "main() guarded by `if [[ \"${BASH_SOURCE[0]}\" == \"${0}\" ]]` so the file is safely sourceable from unit tests"
    - "Pure-bash YAML walker for manifest.yaml — state machine with in_questions flag, BASH_REMATCH regex, double-quote stripping"
    - "Extracted cka_sim::drill::_validate_picked helper so question-selection logic is unit-testable without on-disk pack dir"

key-files:
  created:
    - cka-sim/tests/fixtures/manifest/storage.yaml — single-question parser fixture
    - cka-sim/tests/fixtures/manifest/multi.yaml — 3-question parser fixture
    - cka-sim/tests/fixtures/manifest/empty.yaml — empty-questions (negative) fixture
    - cka-sim/tests/cases/drill_load_pack.sh — manifest parser test
    - cka-sim/tests/cases/drill_question_selection.sh — index validation test
    - cka-sim/tests/cases/drill_namespace_construction.sh — TRIP-03 ns format test
    - cka-sim/tests/cases/drill_orchestration_order.sh — reset/setup/grade/reset order test
  modified:
    - cka-sim/lib/cmd/drill.sh — 13-line stub replaced with full (~290 LOC) orchestrator

key-decisions:
  - "Extracted cka_sim::drill::_validate_picked as a testable helper rather than inlining index validation in load_pack — keeps unit tests offline (no need to seed a real question dir to exercise selection logic)."
  - "Wrapped main() invocation in BASH_SOURCE guard so tests can source drill.sh to access its functions without firing main. Tests also call `set +e` after sourcing since drill.sh sets -e but the test contract uses -uo pipefail (accumulate failures)."
  - "Used comment-skipping regex `^[[:space:]]{2}-[[:space:]]+id:` in render_header's catalog count instead of bare `grep -c 'id:'` which would over-count comment lines."
  - "Namespace pack prefix (e.g. services-networking) pushes longest expected ns name to 31 chars (\"cka-sim-cluster-architecture-99\") — still well under RFC 1123's 63-char limit, verified in drill_namespace_construction.sh."

patterns-established:
  - "drill.sh as thin glue: delegates to lib/preflight.sh for cluster checks, lib/log.sh for UX, per-question subprocesses for lifecycle — per RESEARCH §'Don't Hand-Roll' table."
  - "Unit tests that need drill.sh's functions source the file after setting `set +e` to escape its set -euo pipefail (tests use -uo only)."
  - "Fixture dir convention: cka-sim/tests/fixtures/<feature>/ for input YAML consumed by tests (mirrors existing assert_*/ fixture dirs from Phase 2)."

requirements-completed: [RUN-02, TRIP-03, TRIP-05]

# Metrics
duration: ~12min
completed: 2026-05-10
---

# Phase 3 Plan 02: Drill Orchestrator Summary

**Full `cka-sim drill <pack> [<n>]` orchestrator replacing the Phase 1 stub — pure-bash YAML parser, EXIT-trap cleanup, mktemp+atomic-mv report file, 4 offline unit tests covering parser, index selection, namespace format, and orchestration order.**

## Performance

- **Duration:** ~12 min
- **Tasks:** 2 of 2 complete
- **Files created:** 7 (3 manifest fixtures + 4 unit tests)
- **Files modified:** 1 (cka-sim/lib/cmd/drill.sh — stub replaced)

## Accomplishments

- drill.sh implements the complete RUN-02 contract end-to-end: preflight check, manifest load, question selection (random or 1-based), reset/setup/prompt/grade lifecycle, and EXIT-trap reset on any exit.
- Every RESEARCH-called-out pitfall is sidestepped: Pitfall 1 (tee race) via mktemp+atomic mv, Pitfall 2 (function-scoped EXIT trap) via main()-body trap registration, Pitfall 4 (EOF as ambiguous skip) via explicit `read || action=skip`, Pitfall 5 (corrupted state from sourcing graders) via subprocess grade.sh.
- TRIP-03 lab namespace convention (`cka-sim-<pack>-NN` zero-padded) and TRIP-05 orchestration order are now runtime-enforced and unit-tested.
- Bash-tests suite grew from 15 to 19 passing cases; no existing cases regressed.

## Task Commits

Each task was committed atomically:

1. **Task 1: drill.sh orchestrator + manifest fixtures** — `edf92f8` (feat)
2. **Task 2: 4 drill unit test cases** — `0c90bbe` (test)

_Plan metadata commit (this SUMMARY.md) follows._

## Files Created/Modified

- `cka-sim/lib/cmd/drill.sh` — replaced 13-line stub with ~290 LOC orchestrator. 7 functions: `usage`, `_parse_manifest`, `_validate_picked`, `load_pack`, `prompt_ready`, `cleanup`, `render_header` + `main`. Sources lib/colors.sh, lib/log.sh, lib/preflight.sh; deliberately does NOT source lib/grade.sh or lib/traps.sh.
- `cka-sim/tests/fixtures/manifest/storage.yaml` — 1-question fixture for parser test.
- `cka-sim/tests/fixtures/manifest/multi.yaml` — 3-question fixture covering index iteration.
- `cka-sim/tests/fixtures/manifest/empty.yaml` — no-questions fixture (negative path + meta-only parse).
- `cka-sim/tests/cases/drill_load_pack.sh` — parses all 3 fixtures; asserts 14 expected field values.
- `cka-sim/tests/cases/drill_question_selection.sh` — exercises `_validate_picked` for valid 1-based picks, empty→random, and 4 error paths (0, >n, non-numeric, negative).
- `cka-sim/tests/cases/drill_namespace_construction.sh` — verifies zero-pad format across 5 pack names and RFC 1123 DNS label compliance; confirms longest name (31 chars) stays under 63.
- `cka-sim/tests/cases/drill_orchestration_order.sh` — writes stub setup/reset/grade scripts that log to a tempfile; asserts reset→setup→grade→reset sequence, then verifies 6-files-present + 4-files-executable contracts.

## Decisions Made

- **Extracted `_validate_picked` helper.** The plan's Task 2 notes called out that extracting the index-validation logic from `load_pack` into a testable helper keeps tests offline. Implemented as specified — `load_pack` now delegates, and `drill_question_selection.sh` tests the helper directly without needing a real `packs/<pack>/<NN>/` directory tree.
- **`set +e` after sourcing drill.sh in tests.** drill.sh must use `set -euo pipefail` as a fail-fast orchestrator, but the test contract is `set -uo pipefail` (accumulate failures via `case_failed=1`). Added `set +e` immediately after the source line in the two tests that source drill.sh. Documented inline.
- **Comment-skipping regex for catalog version.** Used `grep -cE '^[[:space:]]{2}-[[:space:]]+id:'` rather than bare `grep -c 'id:'` so commented-out entries or field lines named `id:` don't inflate the count. Also suppressed stderr + defaulted to `0` so render_header never fails if catalog.yaml is missing mid-development.

## Deviations from Plan

None — plan executed exactly as written. The plan's own Task 2 reconciled a subtle inconsistency between Task 1 and Task 2 (the BASH_SOURCE guard + `_validate_picked` helper were added in Task 1 per the plan's "Decision" note), and that reconciliation was followed verbatim.

## Issues Encountered

- None during implementation. Initial concern that drill.sh's `set -euo pipefail` would break the accumulate-failures contract in sourcing tests was preempted by the plan; `set +e` immediately after source cleanly separates drill.sh's runtime options from the test harness's.

## Live-Cluster Verification (Human, Pending Wave 3)

Per RESEARCH Open Q1 and CONTEXT "Claude's Discretion — Test fixtures for Phase 3," `cka-sim drill` end-to-end behaviour (running an actual reset.sh → setup.sh → grade.sh cycle on a live cluster) is **human-verified** after the 5 reference questions land in Wave 3 (plan 03-04). Procedure once packs exist (~5 min per question):

1. `cka-sim bootstrap` then `cka-sim doctor` — expect all checks green.
2. `cka-sim drill storage 1` — confirm the lab namespace `cka-sim-storage-01` is created, question.md prints, prompt appears, typing `done` triggers grade.sh, a `.md` report lands under `~/.cka-sim/reports/`, and the namespace is deleted on exit.
3. Re-run `cka-sim drill storage 1` within 30s — confirm the wait-for-Active loop in setup.sh handles the Terminating-ns window (RESEARCH Pitfall 3) and setup.sh completes.
4. `cka-sim drill storage 1` then Ctrl-C at the prompt — confirm EXIT trap still runs reset.sh and the tempfile is removed.
5. Pipe `echo done | cka-sim drill storage 1` — confirm the EOF path treats piped input as "done" (or skip if an empty line); verify no hang in non-TTY contexts (RESEARCH Pitfall 4).

Unit tests in this plan cover the logic offline; the live-cluster procedure validates shell-interaction and networking paths that cannot be mocked without a full cluster fixture.

## Next Phase Readiness

- Plan 03-03 (lint-packs.sh) can proceed in parallel — drill.sh does not block it.
- Plans 03-04 (5 reference questions) depends on the env-var contract drill.sh exports (CKA_SIM_PACK_ID / QUESTION_ID / LAB_NS / QUESTION_DIR) — all now stable and unit-tested.
- Plan 03-05 (mock-exam composition) reuses the manifest schema + parser established here; future `exam.sh` can either `source lib/cmd/drill.sh` (guard allows it) or re-implement parsing via the same pattern.

## Self-Check: PASSED

- `cka-sim/lib/cmd/drill.sh` — FOUND
- `cka-sim/tests/fixtures/manifest/storage.yaml` — FOUND
- `cka-sim/tests/fixtures/manifest/multi.yaml` — FOUND
- `cka-sim/tests/fixtures/manifest/empty.yaml` — FOUND
- `cka-sim/tests/cases/drill_load_pack.sh` — FOUND
- `cka-sim/tests/cases/drill_question_selection.sh` — FOUND
- `cka-sim/tests/cases/drill_namespace_construction.sh` — FOUND
- `cka-sim/tests/cases/drill_orchestration_order.sh` — FOUND
- Commit `edf92f8` (feat, Task 1) — FOUND
- Commit `0c90bbe` (test, Task 2) — FOUND
- `bash cka-sim/scripts/test.sh` — exits 0, 19/19 cases pass

---
*Phase: 03-runtime-contract-drill-mode*
*Completed: 2026-05-10*
