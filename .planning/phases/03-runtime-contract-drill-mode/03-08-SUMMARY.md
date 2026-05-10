---
phase: 03-runtime-contract-drill-mode
plan: 08
subsystem: packs
tags: [troubleshooting, service, endpoints, deployment, label-selector, grader, detector]

# Dependency graph
requires:
  - phase: 02-grader-core-trap-detectors
    provides: "assert_endpoints_nonempty, record_trap, emit_result, detect_service_label_mismatch (added in 03-01)"
  - phase: 03-runtime-contract-drill-mode
    provides: "lint-packs.sh schema (03-03), troubleshooting catalog entries (03-01)"
provides:
  - "troubleshooting pack manifest + 01-deploy-svc-mismatch reference question (8 files)"
  - "First concrete grader calling assert_endpoints_nonempty + detect_service_label_mismatch in wired form"
  - "Reference Service/Deployment label-vs-selector trap pattern (re-usable for PACK-05 in Phase 6)"
affects: [03-09, 06-PACK-05, 07-orchestration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern: detector-to-catalog-id translation when detector's echoed id is synthetic"
    - "Pattern: merge-patch Service.spec.selector as reference fix (JSON merge, single-line)"

key-files:
  created:
    - cka-sim/packs/troubleshooting/manifest.yaml
    - cka-sim/packs/troubleshooting/README.md
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/metadata.yaml
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/reset.sh
    - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/ref-solution.sh
  modified: []

key-decisions:
  - "Used catalog-registered id service-selector-empty-endpoints for record_trap instead of the detector's synthetic echo service-label-mismatch (not registered in catalog)"
  - "Pinned pod image to nginx:1.27-alpine (small, readinessProbe-friendly, stable patch line)"
  - "Selector mismatch picks app=webserver vs pod label app=web — visually distinct enough that the candidate spots the diff in kubectl get/describe but not so obvious the question feels trivial"
  - "Constraint steers candidate toward Service modification (patch selector) rather than re-labeling pods; ref-solution validates this path"

patterns-established:
  - "Pattern: grader sources lib/grade.sh + lib/traps.sh, uses assert_* + detect_* + record_trap + emit_result, no mutating verbs"
  - "Pattern: detector id normalization — when a detector echoes a non-catalog id, translate to the registered catalog id at record_trap site"

requirements-completed: [TRIP-01, TRIP-02, TRIP-03, TRIP-04, TRIP-05, TRIP-06, GRADE-02, GRADE-03, GRADE-04, GRADE-06, RUN-02]

# Metrics
duration: ~15min
completed: 2026-05-10
---

# Phase 03 Plan 08: Troubleshooting reference question (01-deploy-svc-mismatch) Summary

**Ships a drillable Service-endpoints-empty troubleshooting question where the trap is a Deployment pod label set that doesn't match the Service selector, graded by `assert_endpoints_nonempty` + `detect_service_label_mismatch` wired to the catalog id `service-selector-empty-endpoints`.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 2
- **Files created:** 8
- **Files modified:** 0

## Accomplishments

- Troubleshooting pack scaffold (manifest.yaml weight 30 + README.md) — first and only Phase-3 entry in the troubleshooting domain.
- Reference question `01-deploy-svc-mismatch` fully wired: question prompt, metadata (3 trap ids registered in catalog), and the full runtime triplet (setup/grade/reset) plus ref-solution for GRADE-06 round-trip.
- Grader calls the post-Plan-01 `detect_service_label_mismatch` detector, `assert_endpoints_nonempty` as the core pass/fail pivot, and `record_trap` with the canonical catalog id.
- `bash cka-sim/scripts/test.sh` exits 0 — pack lint (passes A-E), catalog lint, and all 23 bash unit cases green.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold troubleshooting pack + 01-deploy-svc-mismatch metadata** — `12b6f70` (feat)
2. **Task 2: 4 runtime scripts for 01-deploy-svc-mismatch** — `903ec3a` (feat)

_(final metadata commit for SUMMARY.md to follow this file)_

## Files Created/Modified

- `cka-sim/packs/troubleshooting/manifest.yaml` — weight 30, 1 question (7 min estimate).
- `cka-sim/packs/troubleshooting/README.md` — pack overview, points to Phase 6 PACK-05 for remaining questions.
- `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/metadata.yaml` — id, domain=troubleshooting, estimatedMinutes=7, verified_against="1.35", 3 traps (`service-selector-empty-endpoints`, `default-sa-used`, `missing-dns-egress`), 2 references.
- `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md` — candidate prompt; contains no spoiler words (no `label`/`selector`/`match`); steers toward `Modify the Service`.
- `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh` — `set -euo pipefail`; idempotent ns create + Active wait; Deployment `web` (replicas=2, pod label `app=web`, `nginx:1.27-alpine` with readinessProbe); Service `web-svc` with trap selector `app=webserver`.
- `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh` — `set -uo pipefail`; sources lib/grade.sh + lib/traps.sh; asserts Deployment + Service exist; `assert_endpoints_nonempty "$CKA_SIM_LAB_NS" "web-svc"` is the pivot; detector hit records `service-selector-empty-endpoints`; calls `emit_result`.
- `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/reset.sh` — `set -uo pipefail`; async `kubectl delete namespace --ignore-not-found --wait=false`; `exit 0`.
- `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/ref-solution.sh` — `set -euo pipefail`; merge-patch `web-svc.spec.selector` to `{"app":"web"}`.

All four `.sh` scripts are `chmod +x`; `bash -n` clean on all four.

## Decisions Made

- **Synthetic detector id vs catalog id:** `detect_service_label_mismatch` (seeded in Plan 03-01) echoes the literal string `service-label-mismatch`, which is NOT registered in `cka-sim/traps/catalog.yaml`. The equivalent registered catalog id is `service-selector-empty-endpoints` (troubleshooting domain, error severity). Since scope boundary forbids modifying another plan's files (catalog.yaml is 03-01's territory), grade.sh captures the detector's boolean hit and calls `record_trap "service-selector-empty-endpoints"` to satisfy the catalog contract.
- **Pinned image:** `nginx:1.27-alpine` rather than `:latest` per Phase 3 convention (CONVENTIONS.md). Alpine variant is small (~50 MB vs ~180 MB full), and `/` on port 80 is a reliable readiness probe target for `nginx`.
- **Constraint steers toward Service-only fix:** question.md explicitly says "Modify the Service (not the Deployment)" and "Do NOT modify the Deployment or its pod template", so the ref-solution is the single canonical path (merge-patch the Service selector to `{app:web}`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Synthetic detector id not registered in catalog**
- **Found during:** Task 1 metadata draft.
- **Issue:** Plan 03-08 text instructs metadata.yaml and grade.sh to use trap-id `service-label-mismatch`. That id is only emitted by `detect_service_label_mismatch` in `cka-sim/lib/traps.sh`; it is NOT registered in `cka-sim/traps/catalog.yaml`. Both `lint-packs.sh pass E` (via `cka_sim::trap::id_exists`) and runtime `record_trap` `die` on unregistered ids. The catalog instead registers the semantically identical id `service-selector-empty-endpoints` (troubleshooting domain).
- **Fix:**
  - metadata.yaml traps[0] uses `service-selector-empty-endpoints` (satisfies lint pass E).
  - grade.sh still calls `detect_service_label_mismatch` (per the orchestrator's NEW DETECTOR note) but hands the canonical id to `record_trap`:
    ```bash
    tid=$(cka_sim::trap::detect_service_label_mismatch "$CKA_SIM_LAB_NS" "web-svc")
    [[ -n "$tid" ]] && cka_sim::grade::record_trap "service-selector-empty-endpoints"
    ```
- **Files modified:** `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/metadata.yaml`, `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh`.
- **Verification:** `bash cka-sim/scripts/test.sh` exits 0; `lint-packs.sh pass E` accepts all 3 trap-ids.
- **Committed in:** `12b6f70` (metadata.yaml) and `903ec3a` (grade.sh).
- **Follow-up flagged for plan 03-01 owner:** either rename the detector's echoed id to `service-selector-empty-endpoints`, or register `service-label-mismatch` as an alias in the catalog. Until then, this grader carries the translation.

**2. [Rule 1 - Bug] Plan's question.md H1 contained spoiler substring "mismatch"**
- **Found during:** Task 1 acceptance verification.
- **Issue:** Plan verbatim specifies `# troubleshooting/01-deploy-svc-mismatch` as the question.md H1. Plan's own acceptance check `! grep -qiE '(label|selector|match)'` flags `mismatch` → spoiler. Shipping verbatim would have failed the acceptance gate.
- **Fix:** Renamed H1 to `# Troubleshooting: Service has no endpoints` — matches PSI-exam "symptom-stated" style (question.md skeleton from RESEARCH Pattern line 791) and passes the spoiler grep.
- **Files modified:** `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md`.
- **Verification:** `grep -qiE '(label|selector|match)' question.md` → no match; `grep -q 'Modify the ' question.md` → pass.
- **Committed in:** `12b6f70`.

---

**Total deviations:** 2 auto-fixed (1 × Rule 3 blocking, 1 × Rule 1 bug).
**Impact on plan:** Neither deviation alters the question mechanic, the trap, the detector call, or the ref-solution shape. Deviation 1 is a naming-only adjustment at the `record_trap` boundary; the underlying detector body and the trap semantics are unchanged. Deviation 2 is cosmetic (H1 text only).

## Issues Encountered

None during planned work — the two items above were caught before committing and handled via deviation rules.

## User Setup Required

None — troubleshooting pack runs in any namespace the runner constructs (`CKA_SIM_LAB_NS=cka-sim-troubleshooting-01`). Live-cluster human verification (GRADE-06 round-trip `bash setup.sh && bash grade.sh` expecting SCORE < max + 1 trap; then `bash ref-solution.sh && bash grade.sh` expecting SCORE = max + 0 traps) is deferred to Phase 3's final verification pass, not blocking this plan.

## Human-verification procedure (for Phase 03 closeout)

On a cluster with `kubectl` pointed at a workable context:

```bash
export CKA_SIM_ROOT="$(pwd)/cka-sim"
export CKA_SIM_LAB_NS="cka-sim-troubleshooting-01"

# 1. Seed
bash cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh

# 2. Grade under trap — expect: 2/3 pass, 1 fail on endpoints, Trap 1: service-selector-empty-endpoints
bash cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh
# Expected stdout: SCORE: 2/3  + Trap 1: Service selector matches no Ready pods so endpoints are empty: ...

# 3. Apply reference fix
bash cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/ref-solution.sh

# 4. Grade under fix — expect: 3/3, no traps, exit 0
bash cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh
# Expected stdout: SCORE: 3/3  (no Trap lines) ; exit 0

# 5. Reset
bash cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/reset.sh
```

## Next Phase Readiness

- Plan 03-09 (final Phase-3 plan, TBD close-out) has all 5 reference packs in-tree.
- Phase 6 PACK-05 (troubleshooting domain expansion) can clone this scaffold (`01-deploy-svc-mismatch`) as pattern reference; the `detect_service_label_mismatch → record_trap "service-selector-empty-endpoints"` translation is documented and reusable.
- No blockers carried forward; 2 flags documented above.

## Known Stubs

None. All 8 files are complete and wired; no hardcoded empty placeholders, no TODOs.

## Threat Flags

None. This plan adds a Service + Deployment to an ephemeral lab namespace; no new network endpoints, auth paths, or trust boundaries introduced relative to other Phase-3 packs.

## Self-Check: PASSED

- [x] cka-sim/packs/troubleshooting/manifest.yaml — FOUND
- [x] cka-sim/packs/troubleshooting/README.md — FOUND
- [x] cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/metadata.yaml — FOUND
- [x] cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md — FOUND
- [x] cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh — FOUND (executable)
- [x] cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh — FOUND (executable)
- [x] cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/reset.sh — FOUND (executable)
- [x] cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/ref-solution.sh — FOUND (executable)
- [x] Commit 12b6f70 — FOUND in git log
- [x] Commit 903ec3a — FOUND in git log
- [x] `bash cka-sim/scripts/test.sh` — exit 0

---
*Phase: 03-runtime-contract-drill-mode*
*Completed: 2026-05-10*
