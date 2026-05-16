---
phase: 05-services-networking-cluster-architecture-packs
plan: 08
subsystem: pack-authoring
tags: [cluster-architecture, pack-shell, retrofit, sentinel-block, rbac, setup-helpers]

# Dependency graph
requires:
  - phase: 03-runtime-contract-drill-mode
    provides: cluster-architecture pack + 01-rbac-viewer reference question + six-file authoring shape
  - phase: 04-storage-workloads-scheduling-packs
    provides: cka-sim/lib/setup.sh helpers (ensure_lab_ns, wait_for_ns_active), coverage.yaml + lint-coverage.sh contract, retrofit pattern (storage/01-pvc-binding, workloads-scheduling/01-deployment-requests)
provides:
  - Retrofitted cluster-architecture/01-rbac-viewer/setup.sh sourcing lib/setup.sh (inline 24-iteration poll replaced with helper calls)
  - cluster-architecture/manifest.yaml declaring 8 questions via sentinel block (Q01 filled, P09-P15 append Q02-Q08)
  - cluster-architecture/coverage.yaml (PACK-07 domain matrix, rbac-viewer slug + sentinel block for Wave 2 appends)
  - cluster-architecture/README.md (8-question table + sentinel comment block + drill command hints)
affects: [05-09, 05-10, 05-11, 05-12, 05-13, 05-14, 05-15]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sentinel-block idempotent appends (# BEGIN phase-05 new questions / # END phase-05 new questions) for parallel-safe Wave 2 sed -i inserts, grep -q idempotency guards per question-id"
    - "Narrow Phase-N retrofit: source lib helpers only; no grader, metadata, or trap changes (mirrors Phase 4 storage/01-pvc-binding + workloads-scheduling/01-deployment-requests pattern)"

key-files:
  created:
    - cka-sim/packs/cluster-architecture/coverage.yaml
  modified:
    - cka-sim/packs/cluster-architecture/01-rbac-viewer/setup.sh
    - cka-sim/packs/cluster-architecture/manifest.yaml
    - cka-sim/packs/cluster-architecture/README.md

key-decisions:
  - "Sentinel block uses bash-comment syntax (# BEGIN / # END) in manifest.yaml and coverage.yaml and HTML-comment syntax (<!-- BEGIN --> / <!-- END -->) in README.md to stay valid in each format without escaping"
  - "Retrofit preserves question-id cluster-architecture-rbac-viewer, trap set (rbac-viewer-role-mismatch, default-sa-used, missing-dns-egress), and Role verbs: [watch] trap exactly per 05-CONTEXT.md line 21 narrow-retrofit rule"
  - "README.md includes full pack total (8 questions, ~68 min) with only Q01 row populated; P09-P15 append one table row each between sentinel markers"

patterns-established:
  - "Pack-shell scaffold: manifest.yaml + coverage.yaml + README.md with matching sentinel brackets ready for idempotent Wave 2 appends"
  - "Retrofit recipe for Phase-3 reference questions: (1) add CKA_SIM_ROOT guard, (2) source lib/setup.sh, (3) replace inline ns-Active poll with ensure_lab_ns + wait_for_ns_active, (4) preserve all traps and RBAC/resource blocks unchanged"

requirements-completed: [PACK-04, PACK-06, PACK-07]

# Metrics
duration: ~22min
completed: 2026-05-12
---

# Phase 05 Plan 08: Cluster-Architecture Pack Shell + Q01 Retrofit Summary

**Cluster-architecture pack shell ready for 8 questions (Q01 filled via narrow lib/setup.sh retrofit; Q02-Q08 slots declared via sentinel blocks for parallel Wave 2 appends)**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-05-12T00:17:00Z
- **Completed:** 2026-05-12T00:39:00Z
- **Tasks:** 2
- **Files modified:** 3
- **Files created:** 1

## Accomplishments

- Retrofitted `01-rbac-viewer/setup.sh` to source `cka-sim/lib/setup.sh` helpers (40-line inline poll → 2 helper calls) while preserving trap semantics.
- Extended pack `manifest.yaml` to declare 8 questions via sentinel-bracketed block so P09-P15 can append one row each idempotently.
- Created pack `coverage.yaml` (PACK-07 v1.35 Tracker matrix) with `rbac-viewer` tracker slug + sentinel block for Wave 2 appends.
- Updated pack `README.md` with 8-question table + HTML-comment sentinel block + pack total (8 questions, ~68 min).
- All 4 linters (lint-packs, lint-coverage, lint-traps) + test.sh stay green (29/29 cases pass, 51 pack checks pass, 3 packs covered, 25 trap entries pass).

## Task Commits

Each task was committed atomically:

1. **Task 1: Retrofit 01-rbac-viewer/setup.sh to source lib/setup.sh** — `376010a` (refactor)
2. **Task 2: Create pack manifest.yaml + coverage.yaml + README.md** — `3f643d4` (feat)

## Files Created/Modified

- `cka-sim/packs/cluster-architecture/01-rbac-viewer/setup.sh` — Retrofitted to source `lib/setup.sh`; inline 24-iteration ns-Active poll replaced with `cka_sim::setup::ensure_lab_ns` + `cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" cluster-architecture cluster-architecture-rbac-viewer 120`. ServiceAccount `viewer`, Role `pod-viewer` (with `verbs: [watch]` trap), RoleBinding `viewer-binding` preserved unchanged. `chmod +x` + git mode `100755` preserved.
- `cka-sim/packs/cluster-architecture/manifest.yaml` — Extended pack `description` to reflect PACK-04 (25% weight, v1.35 Tracker coverage + CONCERNS.md content replacements). Existing `cluster-architecture-rbac-viewer` question row retained; sentinel block `# BEGIN phase-05 new questions (P09-P15 append below this line -- one row per plan, idempotent)` / `# END phase-05 new questions` added immediately after the Q01 row.
- `cka-sim/packs/cluster-architecture/coverage.yaml` — **NEW**. PACK-07 v1.35 Study Progress Tracker coverage matrix. `domain: cluster-architecture` + `tracker:` section with 1 slug (`rbac-viewer` → `[cluster-architecture-rbac-viewer]`) + sentinel block `# BEGIN phase-05 new questions (P09-P15 append below this line)` / `# END phase-05 new questions` for Wave 2 appends.
- `cka-sim/packs/cluster-architecture/README.md` — Updated PACK-04 blurb (CONCERNS.md content replacements list), changed question table heading to match storage-pack convention (`# | question | tracker slug | est. minutes`), added HTML-comment sentinel block `<!-- BEGIN phase-05 new questions -->` / `<!-- END phase-05 new questions -->`, added pack total line (8 questions, ~68 min) + drill command hint.

## Decisions Made

- Preserved the existing `01-rbac-viewer/setup.sh` ServiceAccount / Role / RoleBinding blocks verbatim (only the namespace-creation prologue was rewritten). 05-CONTEXT.md line 21 explicitly forbids grader/metadata/trap changes in this retrofit, and line 29 clarifies `as-flag-format-wrong` stays as a candidate-detection trap in Phase 3's existing grader logic — not seeded by `setup.sh`.
- Used bash-comment sentinel syntax (`# BEGIN/END phase-05 new questions`) in `manifest.yaml` and `coverage.yaml` but HTML-comment syntax (`<!-- BEGIN/END phase-05 new questions -->`) in `README.md`. Same sentinel payload string so `sed -i` recipes in P09-P15 can target each file with a single regex substitution anchored to the comment body, while each format stays syntactically clean.
- Kept the `README.md` pack-total line (`Pack total: 8 questions, ~68 min.`) outside the sentinel block so it does not drift as rows get appended. P09-P15 only append table rows between the HTML-comment markers.

## Sentinel block convention + sed recipe for P09-P15

**Idempotent append pattern** (each Wave 2 plan runs this once per file it touches):

```bash
# manifest.yaml — append a question row
grep -q 'id: cluster-architecture-<slug>' cka-sim/packs/cluster-architecture/manifest.yaml \
  || sed -i '/# BEGIN phase-05 new questions/a\
  - id: cluster-architecture-<slug>\
    path: NN-<slug>\
    estimatedMinutes: <N>' cka-sim/packs/cluster-architecture/manifest.yaml

# coverage.yaml — append a tracker slug (may span multiple lines)
grep -q '^  <tracker-slug>:' cka-sim/packs/cluster-architecture/coverage.yaml \
  || sed -i '/# BEGIN phase-05 new questions/a\
  <tracker-slug>:\
    label: "<human label>"\
    questions:\
      - cluster-architecture-<qid>' cka-sim/packs/cluster-architecture/coverage.yaml

# README.md — append a table row
grep -q '| NN | \[<slug>\]' cka-sim/packs/cluster-architecture/README.md \
  || sed -i '/<!-- BEGIN phase-05 new questions -->/a\
| NN | [<slug>](NN-<slug>/) | <tracker-slug> | <N> |' cka-sim/packs/cluster-architecture/README.md
```

The `grep -q` guard makes each `sed -i` rerun-safe in isolation. Concurrent commits to the same base branch still race — `<parallel_safety>` in 05-08-PLAN serializes Wave 2 merge-back per pack.

## 7 downstream plans that append to this pack

| Plan  | Adds                                            | Tracker slug              |
| ----- | ----------------------------------------------- | ------------------------- |
| 05-09 | Q02 02-etcd-backup-restore                      | etcd-backup-restore       |
| 05-10 | Q03 03-kubeadm-upgrade                          | kubeadm-upgrade           |
| 05-11 | Q04 04-pss-enforce (CG-10, v1.25+ wording)      | pss-enforce               |
| 05-12 | Q05 05-audit-policy (CG-11)                     | audit-policy              |
| 05-13 | Q06 06-crd-basics (CG-12)                       | crd-basics                |
| 05-14 | Q07 07-cri-dockerd-endpoint (CG-13)             | cri-dockerd-endpoint      |
| 05-15 | Q08 08-priorityclass                            | priorityclass             |

Each plan owns its question directory + single row append in `manifest.yaml`, `coverage.yaml`, and `README.md`.

## Deviations from Plan

None - plan executed exactly as written.

The plan's acceptance-criterion awk expression `awk '/^questions:/,/^[a-zA-Z]/' ... | grep -cE '^\s+- id:' | grep -qx 1` is self-terminating on the `questions:` line itself (both patterns match that single line), so it reports count=0 even on a correctly-shaped manifest. Verified via an alternate awk expression (`awk '/^questions:/{in_q=1;next} in_q && /^[a-zA-Z]/{in_q=0} in_q'`) that the manifest contains exactly 1 question row as intended. Not a deviation — the authored manifest matches the plan's `contains` contract, and downstream Wave 2 plans will add rows correctly regardless of which awk grammar is used.

The plan's Task 2 `lint-deprecated-strings.sh` acceptance-criterion references a script that does not yet exist in `cka-sim/scripts/`; Plan 05-12 creates that script in Wave 2. The criterion is dependency-forward and unreachable until 05-12 lands. The Task 2 content (3 file changes) contains no deprecated strings (`PodSecurityPolicy`, `--container-runtime=remote`, `policy/v1beta1`, `gitRepo:`, `dockershim`), so the criterion will pass automatically once the script exists.

---

**Total deviations:** 0 auto-fixed
**Impact on plan:** None.

## Issues Encountered

- Worktree was branched from `main` rather than `gsd/v1.0-milestone`; `.planning/` + `cka-sim/` were missing. Resolved by `git checkout gsd/v1.0-milestone -- .planning/ cka-sim/` to populate the tree, then `git reset --mixed gsd/v1.0-milestone` to repoint HEAD so subsequent task commits show only the authored delta (not the 350-file seed). No file-content changes were required beyond this — all retrofit work started from the gsd tree content.

## Known Stubs

None. The pack shell intentionally declares 8 question slots with only Q01 filled; the remaining 7 rows are owned by P09-P15 which run in Wave 2 after this plan. The sentinel blocks are a scaffold contract, not a stub.

## Next Phase Readiness

- Pack shell accepts idempotent sentinel-block appends from P09-P15.
- Q01 retrofit preserves FAIL→trap behaviour; still round-trips green under `lint-packs.sh` (51 checks) + `test.sh` (29/29 cases).
- `coverage.yaml` now walked by `lint-coverage.sh` (3 packs: storage, workloads-scheduling, cluster-architecture).

---
*Phase: 05-services-networking-cluster-architecture-packs*
*Completed: 2026-05-12*

## Self-Check: PASSED

Artifacts:
- FOUND: cka-sim/packs/cluster-architecture/01-rbac-viewer/setup.sh
- FOUND: cka-sim/packs/cluster-architecture/manifest.yaml
- FOUND: cka-sim/packs/cluster-architecture/coverage.yaml
- FOUND: cka-sim/packs/cluster-architecture/README.md

Commits:
- FOUND: 376010a (refactor Task 1)
- FOUND: 3f643d4 (feat Task 2)
