---
phase: 04-storage-workloads-scheduling-packs
plan: 05
subsystem: testing
tags: [bash, kubernetes, workloads-scheduling, deployment, setup-helpers, retrofit]

requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/lib/setup.sh (Plan 01) — ensure_lab_ns + wait_for_ns_active helpers
  - phase: 03-runtime-contract-drill-mode
    provides: workloads-scheduling/01-deployment-requests reference question with default-SA + missing-requests traps
provides:
  - Second Wave 2 retrofit: workloads-scheduling/01-deployment-requests/setup.sh now sources lib/setup.sh
  - Proof both Phase 3 reference packs survive migration to shared helpers (test.sh green)
  - Unblocks Wave 3 (Plans 06-15) to author questions against a clean helper library
affects: [04-06-workloads, 04-07-scheduling, 04-08-through-04-15-packs]

tech-stack:
  added: []
  patterns:
    - "shared lib/setup.sh retrofit (Plan 04-04 pattern applied verbatim to workloads pack)"
    - "inline 24-iteration ns-Active loop removed in favor of wait_for_ns_active helper (120s timeout)"

key-files:
  created: []
  modified:
    - cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh

key-decisions:
  - "Kept inline Deployment heredoc (not seed_deployment helper) because the deployment is intentionally broken (no SA + no requests = the trap); helper would fix the trap"
  - "Preserved Deployment YAML byte-for-byte (md5 match confirmed vs pre-change file)"

patterns-established:
  - "Retrofit recipe: source $CKA_SIM_ROOT/lib/setup.sh + ensure_lab_ns + wait_for_ns_active(...,120)"

requirements-completed: [PACK-02, PACK-06]

duration: ~10min
completed: 2026-05-11
---

# Phase 4 Plan 05: Retrofit workloads-deployment-requests setup.sh Summary

**workloads-scheduling/01-deployment-requests/setup.sh now sources cka-sim/lib/setup.sh; 24-line inline ns-Active wait replaced with two helper calls; Deployment trap heredoc preserved byte-for-byte.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-05-11T00:00:00Z (approx, from worktree spawn)
- **Completed:** 2026-05-11T00:14:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Second of two Wave 2 retrofits complete — both Phase 3 reference questions (storage + workloads) now share the ns-Active wait helper
- Deployment heredoc seeding `default-sa-used` + `deployment-missing-requests` traps preserved byte-for-byte (md5 verified)
- File shrinks 62 → 39 lines (-23, -37%)
- `bash cka-sim/scripts/test.sh` green post-change (29/29 unit cases pass, lint-traps + lint-packs clean)

## Task Commits

1. **Task 1: Retrofit workloads-scheduling/01-deployment-requests/setup.sh** — `c256dbf` (refactor)

**Plan metadata:** [pending this SUMMARY commit]

## Files Created/Modified

- `cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh` — sources lib/setup.sh, calls ensure_lab_ns + wait_for_ns_active(120); Deployment heredoc preserved

## Decisions Made

- **Kept inline Deployment heredoc (did NOT switch to `seed_deployment` helper):** the Deployment is intentionally broken (no serviceAccountName → defaults to "default" SA; no resources.requests) — both omissions are the traps graders detect. The `seed_deployment` helper accepts `--sa` and `--cpu/--memory` flags but, even with them omitted, its minimal output still differs from the current trap-seeding YAML. Using the helper would risk silently fixing or drifting the traps; the inline heredoc stays (also documented as a constraint in 04-05-PLAN.md).
- **Retrofit matches 04-04 pattern exactly:** source + ensure_lab_ns + wait_for_ns_active(...,120). No divergence — this keeps future helper bug-fixes propagating identically to both reference packs.

## Deviations from Plan

None — plan executed exactly as written.

### Minor note on acceptance-criterion phrasing

The plan criterion `! grep -q 'serviceAccountName' setup.sh` was imprecise: the descriptive comment on line 15 (`# 2. Deployment with NO resources.requests AND NO serviceAccountName ...`) matches the literal string even though the Deployment YAML does NOT set the field (trap preserved).

Verification that actually matters (that the YAML omits the field) was confirmed three ways:
1. md5 of the Deployment heredoc (lines 16-39 new vs lines 38-62 old) matches: `8f727eff17addd2e37847f1407b1c102` on both sides.
2. `diff` between the pre-change heredoc range and post-change heredoc range is empty.
3. The only new `serviceAccountName` mention in the file is the existing trap-describing comment, carried over unchanged from the pre-retrofit file.

No code change needed — this is a documentation observation for the next author: prefer structural assertions (e.g., `yq` on the rendered YAML) over string-level `grep` for trap-absence checks in future plans.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Wave 2 complete. Both Phase 3 reference packs (storage/01-pvc-binding, workloads-scheduling/01-deployment-requests) share cka-sim/lib/setup.sh helpers.
- Wave 3 (Plans 06-15) authors can now `source "$CKA_SIM_ROOT/lib/setup.sh"` with confidence the helpers survive retrofit lint on two production packs.
- Live 1+2 cluster round-trip re-verification for this pack belongs in phase VERIFICATION.md (Plan 16). Static lint + unit suite green is the gate here, per Phase 3's model.

## Self-Check: PASSED

- FOUND: cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh (39 lines, executable, syntax-valid)
- FOUND commit: c256dbf (refactor(04-05): retrofit workloads-deployment-requests setup.sh to lib/setup.sh)
- VERIFIED: `bash cka-sim/scripts/test.sh` → 29/29 unit cases pass, lint-traps + lint-packs clean
- VERIFIED: Deployment heredoc md5 unchanged (`8f727eff17addd2e37847f1407b1c102`)
- VERIFIED: No `for i in $(seq 1 24)` loop remains in setup.sh
- VERIFIED: Helper calls present (`ensure_lab_ns` + `wait_for_ns_active "$CKA_SIM_LAB_NS" workloads-scheduling workloads-deployment-requests 120`)

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-11*
