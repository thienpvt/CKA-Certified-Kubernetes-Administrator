# Phase 8: Blueprint Bravo + Banners + Docs + CI - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning
**Mode:** Interactive discuss

<domain>
## Phase Boundary

Ship the second mock-exam blueprint (bravo), add superseded-content banners to legacy directories, deliver full documentation (README/AUTHORING/SCHEMA/CONTRIBUTING section), and wire CI extensions (shellcheck + validate-local.sh + pack lint enforcement in GHA).

</domain>

<decisions>
## Implementation Decisions

### Blueprint Bravo (MOCK-02)
- **D-01:** Zero slug overlap with blueprint-alpha except troubleshooting domain (only 1 unused question available — 06-broken-kubelet). Troubleshooting reuses 4 from alpha.
- **D-02:** Bravo draw (17 questions, same weighting 10/15/20/25/30):
  - Storage 10% → 2 questions: 03-access-modes-reclaim, 04-csi-volumesnapshot
  - Workloads 15% → 3 questions: 03-configmap-secret-env-volume, 04-hpa-metrics-server, 07-native-sidecar
  - Services-Networking 20% → 3 questions: 01-networkpolicy-egress, 03-coredns-resolution, 04-ingress-path-host
  - Cluster-Architecture 25% → 4 questions: 01-rbac-viewer, 02-etcd-backup-restore, 03-kubeadm-upgrade, 05-audit-policy
  - Troubleshooting 30% → 5 questions: 06-broken-kubelet, 02-netpol-dns-egress, 03-coredns-resolution, 04-debug-node, 05-static-pod-manifest
- **D-03:** Same manifest schema as blueprint-alpha: `durationMinutes: 120`, `estimatedMinutesBudget: [120, 130]`, same disclaimer string, same weighting block.
- **D-04:** Interleave order: no two adjacent questions from the same domain (same rule as alpha).

### Banners (BANNER-01, BANNER-02)
- **D-05:** Banner is a markdown note block (6 lines max) at the very top of each file, before any existing content. Existing content below is NOT modified.
- **D-06:** Banner text pattern:
  ```
  > **Note:** The exercises below are superseded by the interactive exam simulator.
  > See [`cka-sim/`](../cka-sim/) for trap-aware drills, timed mocks, and automated grading.
  > This content remains for reference but is no longer actively maintained.
  ```
- **D-07:** Three files get banners: `exercises/README.md`, `mock-exams/README.md`, root `README.md`.

### Documentation (DOC-01..DOC-04)
- **D-08:** `cka-sim/README.md` — full quickstart replacing the placeholder. Covers: bootstrap → doctor → drill → exam → score workflow. Architecture overview (lib/, packs/, exams/, scripts/).
- **D-09:** `cka-sim/AUTHORING.md` — expand the Phase 3 partial into the full authoring guide. Add: style guide, schema deep-dive, coverage-matrix workflow, CI integration notes, trap registration flow.
- **D-10:** `cka-sim/SCHEMA.md` — new file. YAML schemas for: `metadata.yaml` (question), pack `manifest.yaml`, exam `manifest.yaml`, `traps/catalog.yaml`.
- **D-11:** `CONTRIBUTING.md` — append an "Authoring exam-sim questions" section. Does NOT modify existing content above.

### CI (CI-01, CI-02, CI-03)
- **D-12:** `cka-sim/scripts/validate-local.sh` — new script. Walks `cka-sim/**/*.yaml` with yamllint and `cka-sim/**/*.sh` with shellcheck. Exit 0 only if both pass.
- **D-13:** Shellcheck scope: ALL `cka-sim/**/*.sh` files. Test fixtures that intentionally trigger warnings use `# shellcheck disable=SCXXXX` directives.
- **D-14:** `.github/workflows/validate.yml` extensions:
  - Add `shellcheck` job (install shellcheck, run `validate-local.sh`)
  - Ensure deprecated-strings lint is already wired (it is — Phase 5 added it)
  - Pack lint enforcement already runs via `test.sh` in the `bash-tests` job
- **D-15:** Pack lint (CI-03) enforcement rules already exist in `lint-packs.sh` passes A-H. Phase 8 just documents them and ensures CI gates them (already done via `test.sh`).

</decisions>

<deferred>
## Deferred / Out of Scope

- Phase 1 live bootstrap verification (tracked separately in STATE.md)
- WR-01 full manifest vendoring
- IN-04 assert_custom helper
- HTML/PDF report rendering
</deferred>
