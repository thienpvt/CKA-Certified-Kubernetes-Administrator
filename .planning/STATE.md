---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-05-12T00:19:47.035Z"
last_activity: 2026-05-12 -- Phase 5 planning complete
progress:
  total_phases: 8
  completed_phases: 3
  total_plans: 50
  completed_plans: 33
  percent: 66
---

# State

## Current Position

Phase: 05
Plan: Not started
Status: Ready to execute
Last activity: 2026-05-12 -- Phase 5 planning complete

### Phase 1 outstanding (carried forward)

Phase 1 code shipped 2026-05-07 with all static checks green. Live-cluster verification still pending — see `.planning/phases/01-cluster-bootstrap-runner-skeleton/01-SUMMARY.md` for the 10-minute on-CP-node procedure (`cka-sim bootstrap` once, re-run for idempotency, `cka-sim doctor` exits 0).

### Outstanding verification (requires user to run on CP node)

1. `cka-sim bootstrap` on a clean CP — expect all green; ssh-copy-id may prompt for password once per worker
2. Re-run `cka-sim bootstrap` — expect no duplicate sentinel blocks in ~/.bashrc or ~/.ssh/config
3. `cka-sim doctor` — expect exit 0 (all 8 checks green)

See `.planning/phases/01-cluster-bootstrap-runner-skeleton/01-SUMMARY.md` for the full 10-minute verification procedure.

### Phase 4 deferred bugs (found during live-drill validation 2026-05-11)

Logged from `cka-sim/results.txt` drill run on the live 1+2 cluster. These must be addressed before Phase 4 can be declared fully passed; user chose to defer and stop autonomous execution.

1. **BUG-1 — `storage/04-csi-volumesnapshot/setup.sh` not executable on live cluster.** Windows git dropped the exec bit during the merge path even though the question's authoring plan committed it as 100755. Drill output: `✗ /root/CKA-Certified-Kubernetes-Administrator/cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh not executable`. Fix: re-run `git update-index --chmod=+x cka-sim/packs/storage/04-csi-volumesnapshot/setup.sh` and recommit. Trivial; single-line gap-closure plan.

2. **BUG-3 — `workloads/08-nodeselector-affinity-taints/setup.sh` hardcodes K8s node name `node-02`.** Drill output: `Error from server (NotFound): nodes "node-02" not found`. The SSH alias `node-01`/`node-02` (from Phase 1 BOOT-03) is distinct from the K8s node names visible to `kubectl get nodes`. Fix: setup.sh must discover a non-control-plane Ready worker dynamically via `kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}'` and use that for label/taint operations; reset.sh must mirror the discovery for cleanup. Affects Q08 only.

3. **Not a bug — Q06 `workloads/06-static-pod` SSH preflight refused** because `cka-sim bootstrap` has not yet been run on this cluster. Resolves itself once Phase 1 verification item (1) above runs.

### Phase 4 automated verification (2026-05-11, all green)

- `bash cka-sim/scripts/test.sh` → 29/29 unit cases pass, exit 0
- `bash cka-sim/scripts/lint-packs.sh` → 51 checks pass, exit 0
- `bash cka-sim/scripts/lint-traps.sh` → 25 catalog entries pass schema, exit 0
- `bash cka-sim/scripts/lint-coverage.sh` → 2 packs at 100% Tracker coverage, 0 warnings, exit 0
- 6 of 7 VERIFICATION must-haves passed programmatically; MH-5 (live drill) partially validated (11/13 Qs round-trip correctly; 2 deferred bugs above).

### Phase 4 live-drill validation matrix (2026-05-11)

| Q | Round-trip FAIL→trap | Notes |
|---|---|---|
| storage/01-pvc-binding | ✓ | trap `hostpath-pv-without-nodeaffinity` fired |
| storage/02-storageclass-dynamic | ✓ | trap `pvc-wrong-storageclass` fired |
| storage/03-access-modes-reclaim | ✓ | traps `pv-accessmodes-mismatch` + `reclaim-policy-retain-when-delete-required` fired |
| storage/04-csi-volumesnapshot | ✗ | **BUG-1: setup.sh not executable** |
| storage/05-wait-for-first-consumer | ✓ | trap `pvc-pending-wffc-unscheduled-consumer` fired |
| storage/06-pvc-mount-pod | ✓ | grader correctly reports missing deployment |
| workloads/02-rolling-update-rollback | ✓ | previous session; full PASS 4/4 round-trip |
| workloads/03-configmap-secret-env-volume | ✓ | trap `default-sa-used` fired |
| workloads/04-hpa-metrics-server | ✓ | candidate-run required for metrics-server install; grader FAIL-path correct |
| workloads/05-daemonset | ✓ | trap `daemonset-missing-control-plane-toleration` fired |
| workloads/06-static-pod | — | SSH preflight refused; runs once `cka-sim bootstrap` ran on this CP |
| workloads/07-native-sidecar | ✓ | trap `sidecar-not-native-restartpolicy-always` fired |
| workloads/08-nodeselector-affinity-taints | ✗ | **BUG-3: hardcoded `node-02` K8s node name** |

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

- **Phase 4 live-drill validation incomplete.** 2 deferred bugs (BUG-1, BUG-3) must be resolved before Phase 4 can be declared fully passed. Resolution path: `/gsd-plan-phase 04 --gaps` when ready to fix, then `/gsd-execute-phase 04 --gaps-only`, then re-run live drill on Q04 + Q08 + Q06.
- **Phase 1 live verification** still outstanding (3 bootstrap checks on the CP node). Q06 static-pod depends on this.

### Pending Todos

- Fix BUG-1 (storage/04-csi-volumesnapshot setup.sh exec bit)
- Fix BUG-3 (workloads/08 dynamic worker discovery)
- Run `cka-sim bootstrap` + `cka-sim doctor` on the CP node to unlock Q06 validation
- Re-drill storage/04, workloads/08, workloads/06 after bug fixes
- Resume autonomous with `/gsd-autonomous --from 5` once Phase 4 passes fully
- WR-01 deferred: full vendoring of CSI + metrics-server manifests under `cka-sim/vendor/` with recorded SHA256
- IN-04 deferred: `cka_sim::grade::assert_custom` helper + 6-grader retrofit (library API addition, not a correctness bug)

---
*Reset for milestone v1.0 on 2026-05-07. Phase 4 paused 2026-05-11 at user request after live-drill surfacing 2 deferred bugs.*
