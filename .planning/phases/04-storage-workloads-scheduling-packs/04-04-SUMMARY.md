---
phase: 04-storage-workloads-scheduling-packs
plan: 04
subsystem: infra
tags: [bash, kubectl, cka-sim, storage, pvc, retrofit, lib-setup]

# Dependency graph
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: "lib/setup.sh helper library (Plan 01) — ensure_lab_ns + wait_for_ns_active"
  - phase: 03-runtime-contract-drill-mode
    provides: "GRADE-06 round-trip green for storage/01-pvc-binding (commit a69fe8a)"
provides:
  - "storage/01-pvc-binding/setup.sh sources lib/setup.sh (first Wave-2 retrofit reference)"
  - "Proof that helper library can replace inline 32-line ns-Active wait without regressing test.sh"
affects: [04-05, 04-06, 04-07, 04-08, 04-09, 04-10, 04-11, 04-12, 04-13, 04-14, 04-15, 04-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pack setup.sh sourcing contract: `: \"${CKA_SIM_ROOT:?...}\"` guard followed by `source \"$CKA_SIM_ROOT/lib/setup.sh\"` (matches grade.sh convention)"

key-files:
  created: []
  modified:
    - "cka-sim/packs/storage/01-pvc-binding/setup.sh — 76 -> 51 lines; helper calls replace inline ns create + 24-iteration wait loop"

key-decisions:
  - "Add CKA_SIM_ROOT guard to setup.sh (did not exist in Phase 3 version) — required because we now source lib/setup.sh; mirrors the contract grade.sh already uses"
  - "Keep PV + PVC heredoc blocks inline rather than routing through cka_sim::setup::seed_pv_hostpath — plan explicitly scoped retrofit to ns wait only, preserving trap semantics byte-for-byte; seed_pv_hostpath retrofit is reserved for a future plan"

patterns-established:
  - "Retrofit recipe for existing packs: drop inline ns-Active wait, add CKA_SIM_ROOT guard, source lib/setup.sh, call ensure_lab_ns then wait_for_ns_active <timeout>"

requirements-completed: [PACK-01, PACK-06]

# Metrics
duration: ~5min
completed: 2026-05-11
---

# Phase 4 Plan 04: Retrofit storage/01-pvc-binding setup.sh to lib/setup.sh Summary

**storage/01-pvc-binding/setup.sh now delegates ns create + 120s Active wait to lib/setup.sh helpers; 32-line inline loop removed, trap semantics byte-identical, 29/29 test.sh cases green.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-10T17:09Z
- **Completed:** 2026-05-10T17:13Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Replaced the inline `for i in $(seq 1 24)` ns-Active wait (setup.sh old lines 6-38) with two helper calls
- Added CKA_SIM_ROOT guard + `source "$CKA_SIM_ROOT/lib/setup.sh"` (mirrors grade.sh contract)
- Preserved PV + PVC heredoc blocks byte-for-byte — hostPath PV still seeded WITHOUT nodeAffinity (trap TRIP-01 intact)
- Future bug fixes to the ns-Active wait now land in one place (lib/setup.sh)
- Net: setup.sh shrank from 76 lines to 51 lines (<=55 per plan acceptance)

## Task Commits

Each task was committed atomically:

1. **Task 1: Retrofit storage/01-pvc-binding/setup.sh to source lib/setup.sh** — `e61725a` (refactor)

_No separate metadata commit — plan explicitly excludes STATE.md / ROADMAP.md updates per orchestrator instruction._

## Files Created/Modified
- `cka-sim/packs/storage/01-pvc-binding/setup.sh` — sourced lib/setup.sh, swapped inline ns-Active wait for helpers; PV + PVC heredoc unchanged

## Decisions Made
- **CKA_SIM_ROOT guard added:** Phase 3 setup.sh did not require it; grade.sh already does. Adding it in this retrofit makes the two files consistent and is the natural precondition for sourcing lib/setup.sh.
- **Scope honored strictly:** seed_pv_hostpath helper exists in lib/setup.sh but the plan scopes retrofit to ns wait only. PV block kept as explicit heredoc to preserve labels (`cka-sim/pack`, `cka-sim/question-id`) and trap semantics byte-for-byte. A later plan can migrate the PV seeding separately.

## Deviations from Plan

None — plan executed exactly as written. The YAML bodies of both heredocs match the original file character-for-character; the only non-body changes are the CKA_SIM_ROOT guard, the `source` line, and the two helper calls.

One cosmetic caveat worth logging (not a deviation): the plan's acceptance clause `! grep -q 'nodeAffinity'` is strictly impossible — the original file already contained three `nodeAffinity` comment mentions (shebang header, PV-block header, PVC-block header), and the retrofitted file preserves those comments verbatim. The substantive check (no `nodeAffinity:` YAML field in the PV spec) is satisfied. The pattern would have been better expressed as `! grep -qE '^  nodeAffinity:'`.

## Issues Encountered
None.

## Verification

- `bash -n cka-sim/packs/storage/01-pvc-binding/setup.sh` — syntax OK
- `[[ -x cka-sim/packs/storage/01-pvc-binding/setup.sh ]]` — executable bit set
- `grep 'source.*lib/setup.sh'` — matches line 9
- `grep 'cka_sim::setup::ensure_lab_ns.*storage.*storage-pvc-binding'` — matches line 12
- `grep -E 'cka_sim::setup::wait_for_ns_active.*storage.*storage-pvc-binding.*120'` — matches line 13
- `grep -cE 'for i in \$\(seq 1 24\)'` — 0 matches (inline loop removed)
- `grep -cE 'if \[\[ -z "\$phase" \]\]'` — 0 matches (inline phase fallback removed)
- `grep 'name: q01-app-pv'` — matches line 21
- `grep 'path: /tmp/q01-app-pv'` — matches line 33
- `grep 'name: app-data'` — matches line 42
- `grep -cE 'kubectl[[:space:]]+create'` — 0 matches (TRIP-02 preserved)
- `grep -cE 'kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)'` — 0 matches (D-09 preserved)
- `wc -l` — 51 lines (<= 55 per acceptance)
- `bash cka-sim/scripts/test.sh` — `all 29 case(s) passed`, exit 0

Deferred: live 1+2 cluster GRADE-06 round-trip for storage-pvc-binding — per plan, that belongs in phase-end VERIFICATION.md (Plan 16 triggers it).

## Next Phase Readiness
- Plan 04-05 (second Wave-2 retrofit target) can safely source lib/setup.sh — one pack reference retrofit now has static lint coverage
- Wave-3 plans (Scheduling pack questions) can assume lib/setup.sh helpers are production-ready
- No STATE.md / ROADMAP.md changes per orchestrator instruction

## Self-Check

- File exists: `cka-sim/packs/storage/01-pvc-binding/setup.sh` — FOUND (51 lines)
- Commit exists: `e61725a` — FOUND on worktree-agent-af371b3993590aad5 branch
- test.sh: 29/29 green

## Self-Check: PASSED

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-11*
