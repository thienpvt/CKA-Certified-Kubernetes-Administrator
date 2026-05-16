# Phase 4: Storage + Workloads-Scheduling Packs - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous mode, batch grey-area tables accepted verbatim)

<domain>
## Phase Boundary

Author the two smaller domain packs end-to-end — Storage (10 % weight) and Workloads & Scheduling (15 %) — using the runtime contract and trap framework already shipped in Phases 2–3. Each pack gains enough questions to cover every v1.35 Study Progress Tracker checkbox for that domain, plus the required CG-01 (CSI/VolumeSnapshot), WaitForFirstConsumer (Storage), CG-06 (metrics-server/HPA prereq) and CG-08 (native sidecar) items. Phase exits green when `cka-sim drill storage` and `cka-sim drill workloads-scheduling` can round-trip every question, the coverage-matrix lint reports 100 % for both domains, and every new trap ID is registered in `traps/catalog.yaml` with schema lint green.

</domain>

<decisions>
## Implementation Decisions

### Scope and Coverage Strategy
- Bundle related Tracker topics into one question when they share a natural scenario (e.g. access modes + reclaim policies together); keep 1:1 mapping only where a concept legitimately stands alone. Coverage is asserted by the new lint, not by file count.
- Storage pack total = 6 questions (reuses the existing `01-pvc-binding` reference question + 5 new). Workloads & Scheduling pack total = 8 questions (reuses `01-deployment-requests` + 7 new).
- Ship `scripts/lint-coverage.sh` in this phase that walks every pack, cross-references question `metadata.yaml.traps` and topic tags against a new `cka-sim/packs/<pack>/coverage.yaml`, and fails on missing Tracker checkboxes. Runs for Storage + Workloads now; Phases 5–6 extend it to the remaining packs.
- Question directories follow the sequential `NN-slug/` convention already established in Phase 3 (`01-pvc-binding` → `02-storageclass-dynamic` → `03-access-modes-reclaim` → `04-csi-volumesnapshot` → `05-wait-for-first-consumer` → `06-pvc-mount-pod` for Storage; analogous numbering for Workloads).

### Authoring Pattern and Trap Catalog
- Every question ships the identical six-file shape already proven in Phase 3: `setup.sh`, `grade.sh`, `reset.sh`, `metadata.yaml`, `question.md`, `ref-solution.sh`. No per-question extra files (no `hint.md`, no separate `solution.yaml`) — DF-08 stays deferred to v1.x.
- Add six new trap IDs to `traps/catalog.yaml` in this phase, matching CONCERNS.md seed schema (8 fields each, `references` as structured list):
  - `csi-snapshot-wrong-driver` (Storage)
  - `pvc-pending-wffc-unscheduled-consumer` (Storage)
  - `reclaim-policy-delete-data-loss` (Storage)
  - `pvc-accessmode-rwx-on-rwo-sc` (Storage)
  - `hpa-missing-metrics-server` (Workloads & Scheduling)
  - `sidecar-not-native-restartpolicy-always` (Workloads & Scheduling)
- `ref-solution.sh` stays bash with inline heredoc YAML where a manifest is needed, pure kubectl otherwise — one lint rule for the whole corpus.
- CSI/VolumeSnapshot question is self-contained on the user's 1+2 kubeadm cluster: `setup.sh` detects an existing `VolumeSnapshotClass`; if none, it installs a thin hostpath-csi driver via manifest and `reset.sh` uninstalls it. Idempotent in both directions. No BOOT-* regression — the bootstrap contract is unchanged.

### Runtime + Verification Contract
- `estimatedMinutes` budget: 6–9 minutes per new question (PACK-06 cap stays ≤12). Sum per pack stays well inside MOCK-01's 110–120 minute window so Phase 7 blueprint composition is unconstrained.
- Round-trip self-check (GRADE-06) runs in two places:
  1. `scripts/test.sh` — unit-level round-trip against the PATH-shadowed `kubectl` stubs seeded in Phase 2 (runs in CI via the existing `bash-tests` job).
  2. `scripts/lint-packs.sh` — schema + RFC-1123 + static round-trip lint over every pack directory (runs in CI and locally).
  Live-kubectl round-trip verification against the 1+2 cluster remains a manual VERIFICATION.md checklist item per question, identical to Phase 3.
- New shared helper library `cka-sim/lib/setup.sh` exports `ensure_lab_ns`, `wait_for_ns_active`, `seed_pv_hostpath`, `seed_deployment`. Every new `setup.sh` (and the two existing Phase 3 references, updated in place) sources it. This kills the 120 s ns-Active wait duplication and prevents the Phase 3 regression from drifting.
- Phase 4 VERIFICATION.md must-haves = 7 criteria:
  1. Storage pack has ≥1 question per Tracker checkbox in the Storage domain (lint-coverage.sh asserts).
  2. Workloads & Scheduling pack has ≥1 question per Tracker checkbox in that domain.
  3. Every new question's `metadata.yaml` passes schema lint: `id`, `domain`, `estimatedMinutes ∈ [4,12]`, `verified_against: "1.35"`, `traps: [≥3 IDs]`, `references: [...]`.
  4. Every trap ID referenced by any question exists in `traps/catalog.yaml` (catalog lint).
  5. `cka-sim drill storage` and `cka-sim drill workloads-scheduling` can drill every question in those packs without error (manual 1+2 cluster verification).
  6. All six new trap entries in `traps/catalog.yaml` pass `scripts/lint-traps.sh` (8-field schema, structured references).
  7. `scripts/lint-coverage.sh` reports 100 % Tracker coverage for both domains.

### Claude's Discretion
- Exact question scenarios / broken-state YAML per question (within the topic and trap-ID constraints above).
- Whether to split "access modes + reclaim policies" into one bundled question or two — use the natural break based on how the scenario tells a story, not a fixed rule.
- Per-question success-criteria phrasing inside `grade.sh` (assertion library is fixed from Phase 2; wording is at Claude's discretion).
- Whether `cka-sim/lib/setup.sh` helpers get a leading `cka_` prefix or stay bare — pick whichever reads cleanest once the Phase 3 references are retrofitted.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cka-sim/lib/traps.sh` + `cka-sim/lib/grade.sh` (Phase 2) — assertion + detector helpers every grader composes from.
- `cka-sim/traps/catalog.yaml` (Phase 2 seeded + Phase 3 extensions `pvc-wrong-storageclass`, `pv-accessmodes-mismatch`, `deployment-missing-requests`, `service-selector-empty-endpoints`, `rbac-viewer-role-mismatch`) — already in the schema Phase 4 extends.
- `cka-sim/packs/storage/01-pvc-binding/` and `cka-sim/packs/workloads-scheduling/01-deployment-requests/` — Phase 3 reference questions; six-file shape + pack `manifest.yaml` shape are proven.
- `cka-sim/scripts/test.sh` — bash test harness with PATH-shadowed `kubectl` stub; extend by dropping in new fixtures under `cka-sim/tests/fixtures/`.
- `cka-sim/scripts/lint-traps.sh` — catalog schema lint; new traps just need to satisfy the existing 8-field schema.

### Established Patterns
- Idempotent `setup.sh` / `reset.sh` with `--ignore-not-found`, cka-sim sentinel-guarded mutations, per-question lab namespace `cka-sim-<domain>-NN`.
- 120 s `wait_for_ns_active` pattern (committed `5c421c1` in Phase 3) — now extracted to `cka-sim/lib/setup.sh` so it's one helper, not N copies.
- Grader structure: `source lib/grade.sh` + `source lib/traps.sh`, assertions accumulate (`assert_*` never `die`), emit `SCORE:` + `Trap N:` block on stdout, live tick marks on stderr.
- Pack directory layout: `packs/<slug>/manifest.yaml` + `packs/<slug>/NN-slug/` per question.

### Integration Points
- `cka-sim drill <pack>` subcommand (Phase 3) already picks a question by pack and runs the triplet — adding new questions just needs them to match the existing metadata schema.
- CI `bash-tests` GHA job runs `scripts/test.sh`; extending fixtures lands automatically.
- Coverage-matrix lint (new in this phase) will be invoked from `scripts/validate-local.sh` + the matching `.github/workflows/validate.yml` step.

</code_context>

<specifics>
## Specific Ideas

- The existing Phase 3 reference questions (`01-pvc-binding`, `01-deployment-requests`) must be retrofitted in place to source the new `cka-sim/lib/setup.sh` helpers — do not duplicate the 120 s ns-Active wait.
- CSI/VolumeSnapshot question self-installs a hostpath-csi driver only if no `VolumeSnapshotClass` is found; cleans up in `reset.sh`.
- Sidecar question uses the v1.35 native-sidecar shape (`initContainers[].restartPolicy: Always`), not the legacy multi-container pattern.
- Metrics-server question seeds a broken or missing metrics-server, expects the candidate to install/fix it, and only then runs an HPA assertion — GRADE-02 behavioural assertions, no `kubectl get | grep`.
- Every new `metadata.yaml` declares `verified_against: "1.35"` literally as a string (not 1.35 numeric) — CI lint from Phase 2 checks for the exact token.

</specifics>

<deferred>
## Deferred Ideas

- Cross-pack question links (Troubleshooting references into Storage/Workloads) — belongs in Phase 6 per the ROADMAP dependency chain.
- Hint-reveal feature (DF-08) — remains out of scope; no `hint.md` files.
- Auto-generated coverage-matrix rendering in README — optional, can land in Phase 8 docs.
- CI step that runs `cka-sim drill <pack>` live against `kind` (DF-12 fixture CI) — deferred to v1.x.
- Pack-level README.md polish — minimal README per pack in Phase 4; full polish happens in Phase 8's DOC-01..04.

</deferred>
