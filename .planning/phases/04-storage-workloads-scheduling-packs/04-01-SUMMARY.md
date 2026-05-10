---
phase: 04-storage-workloads-scheduling-packs
plan: 01
subsystem: infra
tags: [bash, kubectl, testing, idempotent-setup, setup-helpers]

# Dependency graph
requires:
  - phase: 03-runtime-contract-drill-mode
    provides: "120s ns-Active wait + reset-race absorber pattern (commit 5c421c1)"
  - phase: 02-trap-framework-assertion-library
    provides: "tests/lib/assert.sh helpers + PATH-shadowed kubectl stub"
provides:
  - "cka-sim/lib/setup.sh with 4 shared helpers consumed by every Phase 4 question setup.sh"
  - "file-backed counter pattern for subshell-crossing kubectl stubs in bash unit tests"
  - "fixture-tree convention for setup_helpers/<helper>/{hit,miss}.json"
affects: [04-02, 04-03, 04-04, 04-05, 04-06, 04-07, 04-08, 04-09, 04-10, 04-11, 04-12, 04-13, 04-14, 04-15, 04-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared setup-helper library under cka-sim/lib/ for per-question setup.sh reuse"
    - "File-backed (mktemp) counters in bash unit tests to survive `$(…)` subshell boundaries"
    - "`export -f kubectl` heredoc-capture pattern (apply -> cat stdin) for YAML-shape assertions"

key-files:
  created:
    - "cka-sim/lib/setup.sh"
    - "cka-sim/tests/cases/setup_helpers_ensure_lab_ns.sh"
    - "cka-sim/tests/cases/setup_helpers_wait_for_ns_active.sh"
    - "cka-sim/tests/cases/setup_helpers_seed_pv_hostpath.sh"
    - "cka-sim/tests/cases/setup_helpers_seed_deployment.sh"
    - "cka-sim/tests/fixtures/setup_helpers/{ensure_lab_ns,wait_for_ns_active,seed_pv_hostpath,seed_deployment}/*.json"
  modified: []

key-decisions:
  - "wait_for_ns_active unit test uses file-backed counter (mktemp) because `phase=$(kubectl get ns ...)` spawns a subshell; shell-variable counter increments die at subshell exit"
  - "apply-capture pattern: stub kubectl to `cat` stdin on apply so heredoc YAML surfaces as function stdout, enabling expect_contains structural assertions without a real cluster"
  - "ns-Active wait extracted verbatim (loop shape, 5s sleep cadence, re-apply on empty-phase branch) from Phase 3 commit 5c421c1 — zero semantic drift, single source of truth for the race absorber"

patterns-established:
  - "setup.sh helpers: 4-function contract (ensure_lab_ns, wait_for_ns_active, seed_pv_hostpath, seed_deployment) consumed by every packs/*/*/setup.sh"
  - "apply-capture test stub: `kubectl() { [[ \"$1\" == apply ]] && cat || return 64; }; export -f kubectl` for heredoc YAML shape assertions"
  - "file-backed counter test stub: write to `$(mktemp)` path exported as env var; read back in parent after subshell-crossing helper call"

requirements-completed: [PACK-01, PACK-02, PACK-06]

# Metrics
duration: ~22min
completed: 2026-05-10
---

# Phase 04 Plan 01: Shared Setup Helper Library Summary

**4-function shared setup library (`cka-sim/lib/setup.sh`) with 120s ns-Active wait extracted verbatim from Phase 3 commit 5c421c1, plus 4 unit cases proving each helper's observable contract.**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-05-10T16:45:00Z
- **Completed:** 2026-05-10T17:05:00Z
- **Tasks:** 2
- **Files modified:** 13 (1 library + 4 test cases + 8 fixtures)

## Accomplishments
- `cka-sim/lib/setup.sh` defines 4 helpers: `ensure_lab_ns`, `wait_for_ns_active`, `seed_pv_hostpath`, `seed_deployment` — all idempotent, sourced once per question
- 120s ns-Active wait + re-apply-on-empty race absorber extracted from Phase 3 commit 5c421c1 into `wait_for_ns_active` so the fix propagates to every Phase 4 question via a single source point (kills the duplicated-wait regression surface)
- 4 unit cases prove each helper's observable contract under PATH-shadowed kubectl stub without needing a live cluster
- Test suite grew 25 → 29 cases, all green under `bash cka-sim/scripts/test.sh`
- File-backed counter pattern documented inline in `setup_helpers_wait_for_ns_active.sh` for future plans that need to assert on subshell-crossing helpers

## Task Commits

1. **Task 1: Create `cka-sim/lib/setup.sh` with 4 helpers** — `7867353` (feat)
2. **Task 2: Create 4 unit cases + 8 fixtures for setup.sh helpers** — `b6ef6f0` (test)

**Plan metadata:** (this commit — docs)

## Files Created/Modified

**Library (1):**
- `cka-sim/lib/setup.sh` — 4 shared helpers sourced by every `packs/*/*/setup.sh`

**Test cases (4):**
- `cka-sim/tests/cases/setup_helpers_ensure_lab_ns.sh` — asserts Namespace YAML emits cka-sim/pack + question-id labels
- `cka-sim/tests/cases/setup_helpers_wait_for_ns_active.sh` — asserts phase-sequence (empty → re-apply → Active) via file-backed counters
- `cka-sim/tests/cases/setup_helpers_seed_pv_hostpath.sh` — asserts PV YAML for both affinity shapes (trap-seeding path vs. pinned)
- `cka-sim/tests/cases/setup_helpers_seed_deployment.sh` — asserts Deployment YAML for 3 flag permutations (minimal, --sa/--cpu/--memory, --replicas)

**Fixtures (8):**
- `cka-sim/tests/fixtures/setup_helpers/ensure_lab_ns/{hit,miss}.json`
- `cka-sim/tests/fixtures/setup_helpers/wait_for_ns_active/{hit,miss}.json`
- `cka-sim/tests/fixtures/setup_helpers/seed_pv_hostpath/{with,without}-affinity.json`
- `cka-sim/tests/fixtures/setup_helpers/seed_deployment/{with-sa,minimal}.json`

## Function Signatures (for downstream plans 04-02 through 04-15)

```bash
cka_sim::setup::ensure_lab_ns <ns> <pack> <question-id>
cka_sim::setup::wait_for_ns_active <ns> <pack> <question-id> [<timeout-seconds=120>]
cka_sim::setup::seed_pv_hostpath <pv-name> <size> <access-mode> <reclaim-policy> <host-path> [<node-affinity-key>]
cka_sim::setup::seed_deployment <ns> <name> <image> [--replicas N] [--sa SA] [--cpu X] [--memory Y]
```

**Sourcing contract** (mirror of lib/grade.sh and lib/traps.sh):
```bash
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
source "$CKA_SIM_ROOT/lib/setup.sh"
```

## Byte-Comparison vs. Phase 3 Commit 5c421c1

Phase 3 `packs/storage/01-pvc-binding/setup.sh` lines 18-38 vs. `lib/setup.sh::wait_for_ns_active`:

| Phase 3 inline                                  | Phase 4 helper                                                                 |
| ----------------------------------------------- | ------------------------------------------------------------------------------ |
| `for i in $(seq 1 24); do`                      | `for i in $(seq 1 "$iterations")` with `iterations=$(( timeout / 5 ))`, default 120 → 24 |
| `phase=$(kubectl get ns ... -o jsonpath=... \|\| echo "")` | Identical                                                              |
| `[[ "$phase" == "Active" ]] && break`           | `[[ "$phase" == "Active" ]] && return 0` (functionally equivalent; returns 0 earlier) |
| Re-apply heredoc on empty `$phase`              | Delegates to `cka_sim::setup::ensure_lab_ns "$ns" "$pack" "$qid"` (same YAML)  |
| `sleep 5`                                       | `sleep 5`                                                                      |
| `[[ "$phase" == "Active" ]] \|\| exit 1`        | `die "ns $ns not Active after ${timeout}s (phase=$phase)"`                     |

**Semantic equivalence:** loop count, poll cadence, re-apply branch, failure behavior all preserved. Default timeout still 120s. The `break` → `return 0` change is a formatting consequence of moving from inline script to a function; observable behavior identical.

**Plan 03 retrofit impact:** The Phase 3 reference questions (`storage/01-pvc-binding`, `workloads-scheduling/01-deployment-requests`) can replace their inline 33-line ns-wait block with two lines:
```bash
cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-pvc-binding
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-pvc-binding
```
No semantic drift; fix for commit 5c421c1 propagates automatically.

## Test Counts

- **Baseline (before this plan):** 25 cases
- **After Plan 04-01:** 29 cases (+4)
- **New cases:** `setup_helpers_ensure_lab_ns`, `setup_helpers_wait_for_ns_active`, `setup_helpers_seed_pv_hostpath`, `setup_helpers_seed_deployment`
- **Regression check:** All 25 pre-existing cases still green (traps_*, grade_*, lint_*, drill_*)

## Decisions Made

- **wait_for_ns_active test uses file-backed counters.** The helper calls `phase=$(kubectl get ns ...)`, and `$(...)` spawns a subshell. Any counter variable incremented inside the stub kubectl dies when the subshell exits, so the parent shell's `get_count`/`apply_count` would stay at 0 forever. Fix: write counter state to `$(mktemp)` files, export the path (not the value), read back in the parent. This pattern generalizes to any future helper that captures kubectl output via `$(...)`.
- **Apply-capture stub.** Helpers end in `kubectl apply -f - <<EOF...EOF`. The production test stub (`tests/bin/kubectl`) doesn't stub `apply`, so per-case we override with `kubectl() { [[ "$1" == apply ]] && cat || return 64; }; export -f kubectl`. This surfaces the heredoc YAML as stdout for `expect_contains` structural assertions — no live cluster required.
- **Helpers don't add labels on seed_pv_hostpath/seed_deployment.** Callers control those labels directly since PV labels are cluster-scoped and Deployment labels vary per question. Keeping the helpers label-free preserves composability.
- **`affinity_block` indentation in seed_pv_hostpath is 2-space-deep.** The heredoc is concatenated into the PV spec at column 0, so the inner `cat <<AFF` produces content starting with `  nodeAffinity:` — 2 spaces to sit under `spec:`. Tested via `expect_contains "nodeAffinity:"` and `key: kubernetes.io/hostname` on the with-affinity path.

## Deviations from Plan

None — plan executed exactly as written.

The original plan (Task 2 File 10) sketched a naive counter stub using `phase_sequence` array + array-index counter. That sketch would have hit the same subshell-persistence trap I flagged mid-execution in the prior session. Swapping to file-backed counters is a test-design refinement inside the same acceptance criteria (re-apply fires exactly once on empty phase, Active returns 0), not a plan deviation — the observable contract the case proves is identical to the one the plan specified.

## Issues Encountered

**Subshell persistence in `wait_for_ns_active` test case.** The helper invokes `phase=$(kubectl get ns -o jsonpath=...)` inside its polling loop. `$(...)` runs the command in a subshell; any counter variable incremented inside the stub `kubectl` function dies when that subshell exits. A naive `get_count=$(( get_count + 1 ))` approach leaves the parent's `get_count` at 0 forever — the helper would see "empty phase" on every iteration, re-apply 24 times, then die after 120s (in test time: instant, because `sleep` is stubbed to `:`). Fix: `mktemp` a counter file, `echo N > $file` inside the stub, `cat $file` in the parent after the helper returns. Works on the first try; test run shows `get_count=2` (one empty, one Active) and `apply_count=1`.

## Next Phase Readiness

- `lib/setup.sh` is sourceable under `CKA_SIM_ROOT=cka-sim/` and covered by 4 unit cases
- Downstream authoring plans (04-04 through 04-15) can source the helpers and focus on per-question YAML without reimplementing the ns-wait loop
- Plan 04-02 (Phase 3 retrofit) can replace the inline ns-wait in the two reference questions with `ensure_lab_ns` + `wait_for_ns_active` calls using the function signatures documented above
- No blockers

## Self-Check: PASSED

- `cka-sim/lib/setup.sh` — FOUND
- `cka-sim/tests/cases/setup_helpers_ensure_lab_ns.sh` — FOUND
- `cka-sim/tests/cases/setup_helpers_wait_for_ns_active.sh` — FOUND
- `cka-sim/tests/cases/setup_helpers_seed_pv_hostpath.sh` — FOUND
- `cka-sim/tests/cases/setup_helpers_seed_deployment.sh` — FOUND
- 8 fixtures under `cka-sim/tests/fixtures/setup_helpers/**/*.json` — FOUND
- Commit `7867353` (Task 1) — FOUND in `git log`
- Commit `b6ef6f0` (Task 2) — FOUND in `git log`
- `bash cka-sim/scripts/test.sh` — exit 0, 29/29 cases green

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
