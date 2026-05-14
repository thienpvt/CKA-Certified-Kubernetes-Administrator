---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-05-14T13:52:46.750Z"
last_activity: 2026-05-14 -- Phase 07 execution started
progress:
  total_phases: 8
  completed_phases: 6
  total_plans: 75
  completed_plans: 64
  percent: 85
---

# State

## Current Position

Phase: 07 (exam-mode-blueprint-alpha-reporting) — EXECUTING
Plan: 7 of 7 (gap-closure 07-07 — in progress, at human-verify checkpoint)
Status: Executing Phase 07
Last activity: 2026-05-14 -- 07-07 Task 4 done (949e08b); paused at Task 5 human-verify checkpoint

### Deferred Verification

These are intentionally deferred, not blockers for advancing.

1. **Phase 1 live bootstrap verification** — CLOSED. Bootstrap SSH code exists and is functional. Q06-static-pod requires running `cka-sim bootstrap` once on CP to distribute SSH keys to workers. Nodes accessed via `gcloud ssh` from Cloud Shell for management; inter-node SSH handled by bootstrap.

2. **Phase 2 UAT** — CLOSED (2026-05-13). All 5 tests pass (unit suite, catalog lint, assertion helpers, detectors, RFC 1123).
   - Tracking: `.planning/phases/02-trap-framework-assertion-library/02-UAT.md`

3. **Phase 3 UAT** — CLOSED (2026-05-13). All 5 tests pass (drill command, TRIP-02 idempotency, 5-domain round-trip, AUTHORING.md, GRADE-02 lint).
   - Tracking: `.planning/phases/03-runtime-contract-drill-mode/03-UAT.md`

4. **Phase 4 UAT** — CLOSED (2026-05-13). 7/7 pass. Q05/Q08 grader bugs fixed (commits 0916c98, 9c065c3). Q06-static-pod blocked by SSH env (Phase 1 prerequisite).
   - Tracking: `.planning/phases/04-storage-workloads-scheduling-packs/04-UAT.md`

5. **Phase 5 live drill verification** — CLOSED (2026-05-13). All 14 drills pass on live 1+2 cluster.
   - Tracking: `.planning/phases/05-services-networking-cluster-architecture-packs/05-VERIFICATION.md`
   - Final result: 14/14 PASS (6 S&N + 8 CA). Q06 heredoc bug fixed (815e19a). Gaps 1-4,15 closed by plans 05-17..05-20.

6. **Phase 6 live drill verification** — CLOSED (2026-05-13). All 6 troubleshooting drills + host-safety sweep pass on live 1+2 cluster.
   - Tracking: `.planning/phases/06-troubleshooting-pack/06-HUMAN-UAT.md` and `06-VERIFICATION.md`
   - Final result: 22/22 PASS (6 drills × pre-fix + post-fix + host-safety, plus post-sweep with idempotency). Q04 ref-solution fixed (replaced `kubectl debug node` with explicit privileged debug pod manifest carrying same `kubectl.kubernetes.io/debug-source` label).

7. **Phase 7 UAT** — CLOSED (2026-05-13). 9/9 automated tests pass. 2 interactive tests (timer/signals) skipped.
   - Tracking: `.planning/phases/07-exam-mode-blueprint-alpha-reporting/07-UAT.md`
   - Bugs fixed: missing check_jq (53f0d0b), EOF infinite loop (4f49f9a), stdin leak to setup/grade (314cdc0), subshell losing QDIRS array (d196d46), cmd scripts not executable (9ff8312).

### Phase 4 automated verification (2026-05-11, all green)

- `bash cka-sim/scripts/test.sh` → 29/29 unit cases pass, exit 0
- `bash cka-sim/scripts/lint-packs.sh` → 51 checks pass, exit 0
- `bash cka-sim/scripts/lint-traps.sh` → 25 catalog entries pass schema, exit 0
- `bash cka-sim/scripts/lint-coverage.sh` → 2 packs at 100% Tracker coverage, 0 warnings, exit 0
- Phase 4 live-drill bugs BUG-1 and BUG-3 are resolved:
  - `cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh` is tracked executable (`100755`).
  - `workloads-scheduling/08-nodeselector-affinity-taints` discovers the first non-control-plane worker dynamically in `setup.sh`, `reset.sh`, `ref-solution.sh`, and `grade.sh`.

## Accumulated Context

### Decisions

- 2026-05-07 — Rebuild new exam-sim packs from the v1.35 Study Progress Tracker; existing 31 exercises kept as superseded reference-only (not deleted, not retrofitted).
- 2026-05-07 — Target OS: Ubuntu 22.04 (matches PSI real exam env).
- 2026-05-07 — Existing cluster only — no VM provisioning, no `kubeadm init/join` automation.
- 2026-05-07 — Per-question runtime triplet: `setup.sh` / `grade.sh` / `reset.sh`, bash-only, idempotent.
- 2026-05-07 — Grader emits named `Trap N: <description>` diagnostics, not just pass/fail.
- 2026-05-07 — Ship both `cka-sim drill` (single Q) and `cka-sim exam` (timed 2h mock) in v1.0.
- 2026-05-07 — Build five domain packs + two mock-exam packs; mocks compose from packs by reference, never copy.
- 2026-05-07 — SSH topology: candidate works from the control-plane node.
- 2026-05-07 — Bootstrap does NOT inject shell aliases or modify `~/.vimrc`; candidate practices full `kubectl`/`crictl`/`etcdctl` commands for muscle memory. Aliases are opt-in post-bootstrap.
- 2026-05-07 — All K8s resource names (namespaces, cluster-scoped objects, trap IDs, pack IDs) must conform to RFC 1123: lowercase `[a-z0-9-]`, ≤63 chars, alphanumeric start/end. CI-enforced.
- 2026-05-09 — Phase 2 detector contract: explicit per-trap call from grader; positional args + stdout returns trap-id; finalizer formats `Trap N` line from catalog; pure-bash YAML parser (no yq).
- 2026-05-09 — Phase 2 grader contract: failed assertions accumulate (no `die`); each assertion = 1 point; live `✓`/`✗` to stderr, `SCORE:`/`Trap N:` block to stdout; trap dedup by id.
- 2026-05-09 — Phase 2 test harness: PATH-shadowed `kubectl` stub + plain-bash runner; lives at `cka-sim/scripts/test.sh`; new GHA `bash-tests` job; hit/miss/benign fixtures per detector.
- 2026-05-09 — Phase 2 catalog schema: 8 fields per entry (id/name/description/remediation_hint/references/severity/domain/source); `references` is structured `{kind,target,note}`; `lint-traps.sh` enforces schema + paths + seed completeness; `record_trap` validates id at runtime.
- 2026-05-10 — Phase 3 setup-script ns-Active wait extended to 120 s + re-apply if phase=empty; absorbs the `reset.sh --wait=false` race in both drill-driven and bash-driven round-trips. Commit `5c421c1`.
- 2026-05-10 — Phase 3 verified passed on live 1+2 cluster: all 5 reference questions round-trip green (fail_rc!=0 under trap, pass_rc==0 under ref-solution); criterion 1 drill run and criterion 2 TRIP-02 idempotency both confirmed.
- 2026-05-10 — Phase 4 shared helper lib `cka-sim/lib/setup.sh` with 4 functions (ensure_lab_ns, wait_for_ns_active, seed_pv_hostpath, seed_deployment) replaces Phase 3's inline 120 s wait loop; Phase 3 references retrofitted in place.
- 2026-05-10 — Phase 4 trap catalog grew 13 → 25 entries (6 originally locked + 1 W3-revision + 5 on-topic replacements from code review fixes).
- 2026-05-11 — Phase 4 code review landed 3 Critical + 12 Warning fixes in-tree (18 commits `cd73836..3fc45ff`); IN-04 grader-helper refactor and WR-01 full manifest vendoring deferred as non-correctness follow-ups.

### Blockers

- None. All phases verified and closed.

### Pending Todos

- WR-01 deferred: full vendoring of CSI + metrics-server manifests under `cka-sim/vendor/` with recorded SHA256 (non-correctness enhancement)
- IN-04 deferred: `cka_sim::grade::assert_custom` helper + 6-grader retrofit (library API addition, not a correctness bug)

---
