---
phase: 02-trap-framework-assertion-library
plan: 01
subsystem: grading
tags: [bash, assertions, trap-framework, rfc1123, kubectl, sourceable-lib]

# Dependency graph
requires:
  - phase: 01-cluster-bootstrap-runner-skeleton
    provides: "cka-sim/lib/{log,colors}.sh helpers, source-guard idiom, cka_sim:: namespace convention, set -uo pipefail accumulator pattern from doctor.sh"
provides:
  - "cka-sim/lib/traps.sh: RFC 1123 id validator + pure-bash catalog parser + catalog map (6 associative arrays) + id_exists + format_line"
  - "cka-sim/lib/grade.sh: 7 assertion helpers (GRADE-01 verbatim names) + record_trap (runtime catalog validation + dedup) + emit_result finalizer + 5 accumulator globals"
  - "stderr/stdout output contract (D-07): ok/err status on stderr; SCORE + Trap N: lines on stdout"
affects: [02-02, 02-03, 02-04, 02-05, phase-3-reference-graders, phase-7-exam-aggregator]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sourceable helper-module shape under cka-sim/lib/ (traps.sh, grade.sh — matches Phase 1's preflight.sh/log.sh/colors.sh/fileblock.sh)"
    - "Double-namespace prefix on public functions: cka_sim::trap::*, cka_sim::grade::*"
    - "Underscore-prefix on private helpers inside lib modules: cka_sim::trap::_load_catalog"
    - "Associative-array-per-field catalog state: CKA_SIM_TRAP_{NAME,DESC,REMEDIATION,SEVERITY,DOMAIN,SOURCE}[id]"
    - "Accumulator globals (declare -ag/-gi) shared across sourced grader stages: CKA_SIM_GRADE_{FAILS,PASSES,TRAPS,TOTAL,PASSED}"
    - "Lazy catalog load inside id_exists so graders don't have to bootstrap the parser themselves"
    - "Argv parser: fixed leading positionals, then flag pairs in any order (loop-based), then optional trailing numeric weight, then die on anything unexpected"
    - "Assertion helpers return 0/1 but never die — graders with set -uo pipefail keep running to aggregate all failures (D-05)"

key-files:
  created:
    - cka-sim/lib/traps.sh
    - cka-sim/lib/grade.sh
  modified: []

key-decisions:
  - "Lazy catalog load via id_exists — _load_catalog is not called at module top-level so sourcing succeeds before plan 02-02 creates traps/catalog.yaml"
  - "Two-pass parser: pass 1 populates the six maps line-by-line; pass 2 verifies every claimed entry has all six required fields filled (empty-string sentinel detects missing lines)"
  - "emit_result returns rather than exits — graders decide their own exit semantics (cka_sim::grade::emit_result; exit $?)"
  - "Pure-bash parser targets the flat 6-field entry shape only; the references: sub-list is skipped at runtime and validated only by lint-traps.sh in plan 02-05"

patterns-established:
  - "RFC 1123 validator as single source of truth (cka_sim::trap::is_valid_id) — lint-traps.sh (02-05) and record_trap (D-16) both call it"
  - "Argv parser algorithm shared verbatim across assert_resource_exists, assert_field_eq, assert_can_i (plan's MANDATORY algorithm)"
  - "Trap dedup by id-array scan inside record_trap (D-08) — linear scan is fine at the ≤8-traps-per-question scale"

requirements-completed: [GRADE-01, TRIP-07]

# Metrics
duration: ~12min
completed: 2026-05-09
---

# Phase 2 Plan 01: Trap Framework + Assertion Library (grade.sh + traps.sh scaffolding) Summary

**Shipped the two sourceable bash libraries every Phase 3+ grader will consume: `grade.sh` with 7 named assertion helpers + a record_trap/emit_result state machine (GRADE-01), and `traps.sh` with the RFC 1123 validator, pure-bash catalog parser, and runtime lookup helpers (TRIP-07).**

## Performance

- **Duration:** ~12 min
- **Tasks:** 2
- **Files created:** 2 (435 LOC total: 154 traps.sh + 281 grade.sh)
- **Files modified:** 0

## Accomplishments

- `cka-sim/lib/traps.sh` establishes the TRIP-07 naming gate (single source of truth for RFC 1123 validation) and the pure-bash catalog parser (D-04) that every downstream module — including plan 02-02's detectors, plan 02-05's `lint-traps.sh`, and Phase 3+ graders — will use to resolve trap-ids into human-readable lines.
- `cka-sim/lib/grade.sh` delivers all seven verbatim assertion helpers mandated by GRADE-01 (`assert_resource_exists`, `assert_field_eq`, `assert_pod_ready`, `assert_pvc_bound`, `assert_can_i`, `assert_egress_allowed`, `assert_endpoints_nonempty`) plus `record_trap` (D-16 runtime validation + D-08 dedup) and `emit_result` (D-07 stderr/stdout split). Graders source one file to get the full scoring surface.
- Argv parser is implemented per the plan's MANDATORY algorithm in `assert_resource_exists`, `assert_field_eq`, and `assert_can_i` — fixed leading positionals, flag pairs in any order, optional trailing numeric weight, `die` on anything unexpected. Verified against the plan's trace examples.
- Sourcing works with zero setup in both plan-02-01 state (no catalog file yet) and future state (catalog present): top-level `_load_catalog` call was deliberately omitted; lazy load happens inside `id_exists` on first call.

## Task Commits

1. **Task 1: traps.sh scaffolding (validator + catalog parser)** — `a3b27e9` (feat)
2. **Task 2: grade.sh with 7 assertion helpers + record_trap + emit_result** — `c40f795` (feat)

## Files Created/Modified

- `cka-sim/lib/traps.sh` — 154 LOC. Exports `cka_sim::trap::is_valid_id`, `cka_sim::trap::_load_catalog`, `cka_sim::trap::id_exists`, `cka_sim::trap::format_line`. Declares 6 `declare -gA` catalog maps + 1 `declare -g` loaded-flag. No detectors yet (plan 02-02 adds them).
- `cka-sim/lib/grade.sh` — 281 LOC. Exports 7 assertion helpers + `record_trap` + `emit_result` (9 namespaced functions total). Declares 3 `declare -ag` arrays + 2 `declare -gi` counters as shared accumulator state.

## Decisions Made

- **Lazy catalog loading:** The plan forbids calling `_load_catalog` at module top level in this plan (catalog file doesn't exist yet — would crash sourcing). Implemented by routing the first lookup in `id_exists` through `_load_catalog` and guarding on `CKA_SIM_TRAP_CATALOG_LOADED`. Once plan 02-02 creates `traps/catalog.yaml`, sourcing flow is unchanged — the first `record_trap` or `format_line` call transparently loads the catalog.
- **Two-pass parser with empty-string sentinels:** Pass 1 claims a slot per id with all six fields initialised to `""`, then fills each field as its line is seen. Pass 2 scans all claimed slots and dies on the first empty-string sentinel (missing field). Keeps the line-by-line walk simple (no branch for field-ordering) and catches both absent lines and lines that set a field to the empty string.
- **Shared argv parser, inlined per helper:** Rather than extract a private helper for the parser, inlined the same `while (( $# > 0 ))` loop verbatim into each of the three flag-accepting helpers. Each helper has a unique set of allowed flags (only `assert_can_i` accepts `--as`) so the bodies diverge slightly; inline keeps the error messages helper-specific and avoids a nullable-flag-table abstraction for three call sites.
- **`emit_result` returns, does not exit:** The plan explicitly requires `return` (not `exit`) so the grader stays in control of its final exit semantics. Verified with a smoke test (`cka_sim::grade::emit_result; echo rc=$?` in a fresh shell returns 0 on clean state and can be wrapped by the caller).

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

During initial verification I wrote a smoke-test harness that misused `CKA_SIM_ROOT` as the catalog-directory path, causing spurious "colors.sh / log.sh not found" errors from `source "$CKA_SIM_ROOT/lib/…"`. Switched to using `_load_catalog`'s optional path argument (`_load_catalog "$TMPDIR/catalog.yaml"`) with `CKA_SIM_ROOT` pointed at the real `cka-sim/` directory, and all expected behaviours (parse OK, die on bad id, die on missing field, dedup, die on unknown trap-id) verified cleanly. No code change was needed — the module was always correct; the harness was not.

## Verification

- `bash -n cka-sim/lib/traps.sh` — syntax OK.
- `bash -n cka-sim/lib/grade.sh` — syntax OK.
- Combined sourcing: `CKA_SIM_ROOT=…/cka-sim bash -c 'source cka-sim/lib/traps.sh && source cka-sim/lib/grade.sh && cka_sim::trap::is_valid_id pss-error-string-mismatch && echo TRIP-07 ok'` — emits `TRIP-07 ok`.
- Full accumulator visible after sourcing grade.sh: `declare -p CKA_SIM_GRADE_{TOTAL,PASSED,FAILS,PASSES,TRAPS}` → 5 `declare` lines.
- Parse OK catalog (2 entries) → `id_exists sample-trap` passes, `format_line 1 sample-trap` prints `Trap 1: Sample trap: One-liner` to stdout.
- Parse bad-id catalog (`BadID`) → dies with `catalog parse failed: invalid id 'BadID' (must match RFC 1123)`, rc=1.
- Parse catalog missing `remediation_hint` → dies with `'<id>' missing field 'remediation_hint'`, rc=1.
- `record_trap sample-trap; record_trap sample-trap; record_trap another-trap` → array length 2 (dedup works).
- `record_trap phantom-id` → dies with `unknown trap-id 'phantom-id' — register it in traps/catalog.yaml first`, rc=1 (D-16).
- `emit_result` on empty state → prints `SCORE: 0/0` to stdout and returns rc=0.
- `assert_resource_exists Pod my-pod -n ns xyz` → dies with `unexpected argument: xyz` (argv parser catches non-flag/non-numeric token).
- `assert_can_i get pods --as alice -n ns` → parser accepts reversed flag order (loop-based, per plan trace).

## Next Phase / Plan Readiness

- **Plan 02-02** now has everything it needs to add detectors to `traps.sh`: the source-guard, namespacing, colors+log sourcing, and catalog-loader interface are all in place. Detectors only need to add `cka_sim::trap::detect_<id>` functions; no header edits.
- **Plan 02-03** (tests harness) can source `traps.sh` and `grade.sh` unchanged. The PATH-shadowed kubectl stub will feed `kubectl` calls made by both detectors (plan 02-02) and assertion helpers (this plan).
- **Plan 02-04** (traps/catalog.yaml) will populate the 6 associative arrays at runtime once `_load_catalog` resolves to a real file. Schema is enforced by plan 02-05's `lint-traps.sh`; runtime parser is tolerant of the schema subset it needs.
- **Plan 02-05** (`lint-traps.sh`) will `source cka-sim/lib/traps.sh` to reuse `is_valid_id` (single source of truth per D-15(b)).
- **Phase 3 graders** source `grade.sh`, which transitively sources `traps.sh` + `log.sh` + `colors.sh`. Grader authors only need the 7 `assert_*` helpers and `record_trap` / `emit_result` — full contract is covered by this plan.

## Open Hooks for Plan 02-02

1. Add `cka_sim::trap::detect_*` functions to `cka-sim/lib/traps.sh` — placeholder comment already marks the spot.
2. Create `cka-sim/traps/catalog.yaml` so `id_exists` resolves to real entries at runtime (record_trap currently dies if asked to record any id because the catalog file does not yet exist).

## Self-Check: PASSED

Files created and present:
- `cka-sim/lib/traps.sh` — FOUND (154 LOC)
- `cka-sim/lib/grade.sh` — FOUND (281 LOC)

Commits reachable from HEAD:
- `a3b27e9` (feat(02-01): add traps.sh scaffolding) — FOUND
- `c40f795` (feat(02-01): add grade.sh with 7 assertion helpers + record_trap + emit_result) — FOUND

---
*Phase: 02-trap-framework-assertion-library*
*Plan: 01*
*Completed: 2026-05-09*
