---
phase: 05-services-networking-cluster-architecture-packs
plan: 02
subsystem: pack-authoring
tags: [services-networking, pack-shell, retrofit, sentinel-blocks, lib-setup-helpers]

# Dependency graph
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: "cka_sim::setup::ensure_lab_ns + wait_for_ns_active helpers; retrofit pattern (storage/01-pvc-binding + workloads-scheduling/01-deployment-requests); lint-packs.sh + lint-coverage.sh schemas"
  - phase: 03-runtime-contract-drill-mode
    provides: "Phase 3 reference question services-networking/01-networkpolicy-egress (pre-retrofit source); six-file question shape"
provides:
  - "Retrofitted services-networking/01-networkpolicy-egress/setup.sh sourcing cka-sim/lib/setup.sh (24-line poll -> 2-line helper call)"
  - "Services & Networking pack manifest.yaml with existing Q01 row + BEGIN/END phase-05 sentinel block for idempotent Wave 2 appends"
  - "Services & Networking pack coverage.yaml (new file) mirroring storage/coverage.yaml shape with netpol-egress tracker + sentinel block"
  - "Services & Networking pack README.md with 6-question placeholder table + HTML-comment sentinel block for Wave 2 table-row appends"
  - "Sentinel-block append convention + copy-paste sed recipe for P03-P07 to use"
affects:
  - 05-03-service-core
  - 05-04-coredns-resolution
  - 05-05-ingress-path-host
  - 05-06-kube-proxy-mode
  - 05-07-netpol-endport

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sentinel-block append: YAML '# BEGIN/END phase-05 new questions' + Markdown '<!-- BEGIN/END phase-05 new questions -->' — Wave 2 plans sed -i...i...before END, guarded by grep-q on question-id for idempotency"
    - "Phase 3 reference-question retrofit — source CKA_SIM_ROOT/lib/setup.sh + ensure_lab_ns + wait_for_ns_active; preserve shebang/strict/ns-label/trap/Pod/NetworkPolicy; git update-index --chmod=+x to pre-empt BUG-1 on Windows"

key-files:
  created:
    - "cka-sim/packs/services-networking/coverage.yaml"
  modified:
    - "cka-sim/packs/services-networking/01-networkpolicy-egress/setup.sh"
    - "cka-sim/packs/services-networking/manifest.yaml"
    - "cka-sim/packs/services-networking/README.md"

key-decisions:
  - "Narrow retrofit scope — only source-lib/setup.sh change to 01-networkpolicy-egress/setup.sh; no grader/metadata/trap/reset changes (per 05-CONTEXT.md §decisions lines 20-21)"
  - "Sentinel block placed immediately before '# END phase-05 new questions' so 'sed -i /pattern/i\\...' appends land inside the block at any Wave 2 ordering"
  - "coverage.yaml seeded with only the 'netpol-egress' tracker slug — the 5 Wave 2 tracker slugs (service-core, coredns-resolution, ingress-path-host, kube-proxy-mode, netpol-endport) land as each plan ships to avoid premature schema-lint failure for unpopulated slugs"
  - "README.md table uses Markdown HTML-comment sentinel (not YAML '#') because lint-packs.sh / lint-coverage.sh never scan README.md, so HTML comments are safely invisible to lint"

patterns-established:
  - "Pack-shell scaffold: manifest.yaml + coverage.yaml + README.md all land together in the shell plan (Wave 1), with parallel-safe sentinel blocks so Wave 2 per-question plans don't conflict on the same line"
  - "Idempotent Wave 2 append recipe: grep -q <qid> <file> || sed -i '/# END phase-05 new questions/i\\  - id: <qid>\\n    path: NN-slug\\n    estimatedMinutes: N' — rerunnable safely in isolation; serialized per-pack at merge-back time (not at branch-diverge time)"

requirements-completed: [PACK-03, PACK-06, PACK-07]

# Metrics
duration: 4min
completed: 2026-05-12
---

# Phase 5 Plan 02: Services-Networking Pack Shell Summary

**Retrofitted `01-networkpolicy-egress/setup.sh` to source `lib/setup.sh` helpers (24-line ns-wait poll collapsed to 2 lines) and scaffolded `services-networking` pack shell with parallel-safe sentinel blocks in `manifest.yaml`, `coverage.yaml`, and `README.md` so Wave 2 plans P03-P07 can idempotently append their rows without line-level merge conflicts.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-12T00:32:10Z
- **Completed:** 2026-05-12T00:35:52Z
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified) + 1 retrofitted = 4 total

## Accomplishments

- Phase 3 reference question `01-networkpolicy-egress` now sources `cka-sim/lib/setup.sh` — 24 lines of inline 24-iteration ns-Active poll + re-apply loop replaced by `cka_sim::setup::ensure_lab_ns` + `cka_sim::setup::wait_for_ns_active 120` (mirrors Phase 4 retrofit of storage/01-pvc-binding and workloads-scheduling/01-deployment-requests).
- `services-networking/manifest.yaml` expanded to full-domain pack description, keeping Q01 as the only populated row with a `# BEGIN phase-05 new questions` / `# END phase-05 new questions` sentinel block below it for P03-P07 appends.
- `services-networking/coverage.yaml` created (new file) with one seeded tracker slug (`netpol-egress` -> `services-networkpolicy-egress`) and a sentinel block for P03-P07 tracker-block appends.
- `services-networking/README.md` replaced with PACK-03 description + 6-question placeholder table pre-populated with Q01 row + HTML-comment sentinel block for table-row appends.
- `scripts/lint-packs.sh` green (51 checks) and `scripts/lint-coverage.sh services-networking` green (1 pack, 0 warnings) after scaffolding.
- `scripts/test.sh` green (29 unit cases) — no behaviour regression in the retrofitted setup.
- Sentinel-block sed-append recipe validated via in-place dry-run on both `manifest.yaml` and `coverage.yaml` — idempotent rerun is a no-op, and the lint-coverage parser handles the inserted block cleanly.

## Task Commits

Each task was committed atomically:

1. **Task 1: Retrofit `01-networkpolicy-egress/setup.sh`** — `47563f2` (refactor)
2. **Task 2: Create pack manifest.yaml + coverage.yaml + README.md** — `a3ec284` (feat)

## Files Created/Modified

- `cka-sim/packs/services-networking/01-networkpolicy-egress/setup.sh` (modified) — sources `CKA_SIM_ROOT/lib/setup.sh`; replaces inline 24-iteration ns-Active poll with `cka_sim::setup::ensure_lab_ns` + `wait_for_ns_active 120`; preserves trap (`missing-dns-egress`), question-id label (`services-networkpolicy-egress`), probe Pod (`nicolaka/netshoot:v0.13`), NetworkPolicy `egress-restrict`, and readiness wait.
- `cka-sim/packs/services-networking/manifest.yaml` (modified) — pack description expanded to full-domain scope; Q01 row preserved; `# BEGIN phase-05 new questions` / `# END phase-05 new questions` sentinel block inserted.
- `cka-sim/packs/services-networking/coverage.yaml` (created) — mirrors `storage/coverage.yaml` shape; seeds `netpol-egress` tracker slug referencing `services-networkpolicy-egress`; sentinel block for P03-P07 tracker blocks.
- `cka-sim/packs/services-networking/README.md` (modified) — PACK-03 description; 6-question table pre-populated with Q01 row + HTML-comment sentinel block for P03-P07 table-row appends.

## Decisions Made

- Retrofit kept source-only per 05-CONTEXT.md lines 20-21. No grader/metadata/trap/reset changes. Existing behaviour preserved end-to-end — trap `missing-dns-egress` still fires via identical NetworkPolicy spec.
- Sentinel block placed immediately before `# END phase-05 new questions` so `sed -i '/# END.../i\<content>'` inserts at that anchor line regardless of Wave 2 execution ordering — P03, P04, P05, P06, P07 can each run in isolation and produce a valid intermediate file.
- `coverage.yaml` seeded with only the `netpol-egress` tracker slug. The remaining 5 Wave 2 slugs (`service-core`, `coredns-resolution`, `ingress-path-host`, `kube-proxy-mode`, `netpol-endport`) land as each plan ships. This is deliberate — seeding empty slugs upfront would fire the `lint-coverage.sh` "tracker slug has empty questions list" error.
- README.md uses Markdown HTML-comment sentinel (`<!-- BEGIN ... -->` / `<!-- END ... -->`) rather than YAML `#`. `lint-packs.sh` and `lint-coverage.sh` never scan README.md, so sentinel choice is cosmetic, but HTML comments render invisibly in Markdown previewers.
- BUG-1 pre-empt: `git update-index --chmod=+x` committed with the retrofit — Windows `core.fileMode=false` strips the exec bit, so the git index carries `100755` explicitly.

## Deviations from Plan

None — plan executed exactly as written.

The two Task 2 acceptance criteria that reference `scripts/lint-deprecated-strings.sh` (future Phase 5 P01 deliverable) and an awk-range question-row count (self-terminating range in the plan text; `grep -cE '^[[:space:]]+- id: '` confirms 1 row as intended) were evaluated inline — both resolve to the spec'd intent even though the literal commands don't apply. No deviation rule invoked, no auto-fix applied.

## Issues Encountered

**Worktree base drift (pre-execution, not a code issue):**

The worktree branch (`worktree-agent-a5d008a69b2874176`) was created from `main` (5500f29) by the tooling instead of from `gsd/v1.0-milestone` (ce1ba53). The other Wave 1 worktrees (`a65c33fda1bb8f3d1`, `a8f6d9d934e49e233`) were correctly based on `gsd/v1.0-milestone`. Resolved by running `git merge gsd/v1.0-milestone --no-edit` at the start of execution, which merged the full phase-5 planning tree and Phase 4 pack content into the worktree as a fast-forward-style merge commit. All subsequent task commits sit on top of this merge and carry only the plan-specific file changes — no unrelated content.

**Impact on plan:** zero. The merge was surgical (base-branch content only, no conflicts) and the final commit tree presents exactly the 2 task commits the plan prescribes. Flagged for the orchestrator in case the worktree-spawn bug needs fixing in the Wave 1 dispatch logic.

## Sentinel-block append recipe (for P03-P07)

The Wave 2 plans append rows to the three pack-level files. The exact recipe each plan uses:

```bash
# manifest.yaml — one question block per plan
QID="services-service-core"   # per Wave 2 plan
grep -q "$QID" cka-sim/packs/services-networking/manifest.yaml || \
  sed -i "/# END phase-05 new questions/i\\  - id: $QID\\n    path: 02-service-core\\n    estimatedMinutes: 7" \
    cka-sim/packs/services-networking/manifest.yaml

# coverage.yaml — one tracker block per plan
SLUG="service-core"
grep -q "^  $SLUG:" cka-sim/packs/services-networking/coverage.yaml || \
  sed -i "/# END phase-05 new questions/i\\  $SLUG:\\n    label: \"Service core: ClusterIP/NodePort/Endpoints\"\\n    questions:\\n      - $QID" \
    cka-sim/packs/services-networking/coverage.yaml

# README.md — one table row per plan
grep -q "$QID" cka-sim/packs/services-networking/README.md || \
  sed -i "/<!-- END phase-05 new questions -->/i\\| NN | [slug](NN-slug/) | $SLUG | N min |" \
    cka-sim/packs/services-networking/README.md
```

Idempotency: the `grep -q` guard skips the append if the qid or slug already appears. Safe on rerun.

Parallel merge-back: per plan `<parallel_safety>` block, serialization happens at merge-back-to-base, not at worktree-spawn. P03-P07 each push to a worktree branch, then rebase onto the prior plan's merge before merging — git's text-level three-way merge between two adjacent-line inserts inside the sentinel block can be ambiguous, so execute-phase serializes.

## Downstream plans that append to this pack shell

Wave 2 plans (05-03 through 05-07) each append one question block to manifest.yaml + one tracker block to coverage.yaml + one table row to README.md:

| Plan | Question id | Path | Tracker slug | Est min |
|------|-------------|------|--------------|---------|
| 05-03 | services-service-core | 02-service-core | service-core | 7 |
| 05-04 | services-coredns-resolution | 03-coredns-resolution | coredns-resolution | 7 |
| 05-05 | services-ingress-path-host | 04-ingress-path-host | ingress-path-host | 8 |
| 05-06 | services-kube-proxy-mode | 05-kube-proxy-mode | kube-proxy-mode | 8 |
| 05-07 | services-netpol-endport | 06-netpol-endport | netpol-endport | 7 |

After all 5 Wave 2 plans land, pack total = 6 questions, ~46 min, 100% v1.35 S&N Tracker coverage (per 05-CONTEXT.md §decisions line 18).

## Next Phase Readiness

- Pack shell is ready for Wave 2 S&N plans (05-03 through 05-07) to execute in parallel.
- Sentinel blocks validated via dry-run append recipe — no merge-conflict risk within a single plan's commit.
- Retrofit preserves Q01 behaviour; next re-drill of `01-networkpolicy-egress` against the live 1+2 cluster should round-trip identically (verification deferred to Phase 5 VERIFICATION.md MH-5, covered by Plan 05-11).
- No STATE.md / ROADMAP.md writes from this worktree per parallel-executor contract — orchestrator owns those after all Wave 1 plans merge.

## Self-Check

- [x] `cka-sim/packs/services-networking/01-networkpolicy-egress/setup.sh` exists and sources lib/setup.sh
- [x] `cka-sim/packs/services-networking/manifest.yaml` exists with BEGIN/END sentinels
- [x] `cka-sim/packs/services-networking/coverage.yaml` exists with BEGIN/END sentinels
- [x] `cka-sim/packs/services-networking/README.md` exists with HTML-comment sentinels
- [x] Commit `47563f2` (refactor retrofit) exists in `git log`
- [x] Commit `a3ec284` (feat pack shell) exists in `git log`
- [x] `bash cka-sim/scripts/lint-packs.sh` exits 0 (51 checks)
- [x] `bash cka-sim/scripts/lint-coverage.sh services-networking` exits 0 (1 pack, 0 warnings)
- [x] `bash cka-sim/scripts/test.sh` exits 0 (29 cases)
- [x] Sentinel-block sed-append recipe dry-run produces valid manifest + coverage YAML with idempotent rerun

## Self-Check: PASSED

---
*Phase: 05-services-networking-cluster-architecture-packs*
*Completed: 2026-05-12*
