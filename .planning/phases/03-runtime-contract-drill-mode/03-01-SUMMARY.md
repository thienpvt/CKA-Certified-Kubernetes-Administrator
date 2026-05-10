---
phase: 03-runtime-contract-drill-mode
plan: 01
subsystem: content
tags: [yaml, trap-catalog, lint, rbac, storage, services-networking, workloads-scheduling]

# Dependency graph
requires:
  - phase: 02-grader-contract-trap-catalog
    provides: "8 seeded trap entries + pure-bash parser + lint-traps.sh schema lint"
provides:
  - "5 new trap entries (13 total) in cka-sim/traps/catalog.yaml"
  - "State-detectable RBAC trap 'rbac-viewer-role-mismatch' unblocking cluster-architecture/01-rbac-viewer (D-10 revision per user override #1)"
  - "Storage / workloads / troubleshooting trap IDs that Wave 3 per-question metadata.yaml files can reference without lint-packs rule (c) failing"
affects:
  - 03-runtime-contract-drill-mode  # later waves (03-04..03-08 question packs)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Catalog extension: community-sourced traps skip references[].kind=concerns-md (no CONCERNS anchor) — only k8s-doc reference item(s) per entry"

key-files:
  created: []
  modified:
    - cka-sim/traps/catalog.yaml

key-decisions:
  - "2026-05-10 — New community-sourced trap entries omit kind=concerns-md references (source: community rather than source: concerns-md; no repo-root path enforcement path triggered)."
  - "2026-05-10 — rbac-viewer-role-mismatch is the D-10 state-detectable replacement for as-flag-format-wrong in cluster-architecture/01-rbac-viewer (user override #1). as-flag-format-wrong stays in the catalog as a general text-based trap."

patterns-established:
  - "Community trap entry shape: 8 required fields in canonical order, references[] containing a single k8s-doc item with kind/target/note."

requirements-completed: [GRADE-04]

# Metrics
duration: ~5min
completed: 2026-05-10
---

# Phase 3 Plan 01: Trap Catalog Extension Summary

**5 new trap entries extend cka-sim/traps/catalog.yaml from 8 to 13 — unblocks Wave 3 per-question metadata.yaml files and adds a state-detectable RBAC trap for D-10's revised cluster-architecture/01-rbac-viewer mapping.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-10T04:23:00Z
- **Completed:** 2026-05-10T04:28:20Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Catalog grown from 8 -> 13 entries with `lint-traps.sh` still green (`catalog lint passed (13 entr(ies))`)
- Added `rbac-viewer-role-mismatch` (cluster-architecture / error) — state-detectable RBAC trap per user override #1; Wave 3 plan 03-07 (cluster-architecture/01-rbac-viewer) will declare this in its metadata.yaml `traps[]` instead of `as-flag-format-wrong`
- Added 4 non-RBAC traps exposing common CKA-level misconfigurations: `pvc-wrong-storageclass`, `pv-accessmodes-mismatch`, `deployment-missing-requests`, `service-selector-empty-endpoints`

## Task Commits

1. **Task 1: Add 5 new trap entries to traps/catalog.yaml** — `e9a08ce` (feat)

_Final metadata commit is created by the orchestrator after all wave agents complete._

## Files Created/Modified

- `cka-sim/traps/catalog.yaml` — appended 5 new entries (8 -> 13); field order `id, name, description, remediation_hint, severity, domain, source, references` preserved; all new entries `source: community` with a single `kind: k8s-doc` reference (no CONCERNS anchor required)

## New Trap IDs

| ID | Domain | Severity | Purpose |
|---|---|---|---|
| `pvc-wrong-storageclass` | storage | warn | PVC references a non-existent StorageClass, stays Pending |
| `pv-accessmodes-mismatch` | storage | warn | Binder skips PV whose accessModes don't cover PVC's request |
| `deployment-missing-requests` | workloads-scheduling | warn | Containers omit resources.requests -> best-effort QoS + no HPA |
| `service-selector-empty-endpoints` | troubleshooting | error | Service.spec.selector doesn't match pod labels -> empty Endpoints |
| `rbac-viewer-role-mismatch` | cluster-architecture | error | Role/RoleBinding omits required verb-resource or mis-subjects the SA (D-10 revision per user override #1) |

## Decisions Made

- Used `source: community` for all 5 new entries (none are CONCERNS-anchored). Consequently no `references[].kind == concerns-md` items — the catalog stays consistent and `lint-traps.sh:106-110` path-existence check never fires.
- Each new entry carries exactly one reference item (`kind: k8s-doc`) rather than multiple, matching the minimal valid schema the lint accepts.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration introduced.

## Verification

- `bash cka-sim/scripts/lint-traps.sh` -> exit 0; stdout contains literal `catalog lint passed (13 entr`
- `grep -cE '^[[:space:]]{2}-[[:space:]]+id:' cka-sim/traps/catalog.yaml` -> `13`
- All 5 new IDs present in `cka-sim/traps/catalog.yaml`:
  - `pvc-wrong-storageclass`
  - `pv-accessmodes-mismatch`
  - `deployment-missing-requests`
  - `service-selector-empty-endpoints`
  - `rbac-viewer-role-mismatch`
- All 8 seeded IDs still present (implied by lint exit 0; `seed_ids` check in `lint-traps.sh:41-50` passed)

## Next Phase Readiness

- Wave 3 plans (03-04 storage, 03-05 workloads-scheduling, 03-06 services-networking, 03-07 cluster-architecture, 03-08 troubleshooting) can now declare these trap IDs in their per-question `metadata.yaml` `traps[]` without violating lint-packs.sh rule (c).
- Plan 03-07 (cluster-architecture/01-rbac-viewer) MUST reference `rbac-viewer-role-mismatch` (NOT `as-flag-format-wrong`) per user override #1; CONTEXT.md D-10 table ("Seeded trap exercised" cell) should be patched to reflect this during 03-07 execution.
- No blockers for downstream waves.

## Self-Check: PASSED

- File `cka-sim/traps/catalog.yaml` exists, contains 13 `- id:` entries.
- Commit `e9a08ce` present in `git log --oneline -5`.
- New IDs grep-confirmed.
- `lint-traps.sh` exits 0 and prints `catalog lint passed (13 entr(ies)).`

---
*Phase: 03-runtime-contract-drill-mode*
*Completed: 2026-05-10*
