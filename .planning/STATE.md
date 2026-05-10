---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-05-10T14:17:15.000Z"
last_activity: 2026-05-10 -- Phase 3 verified (live 1+2 cluster round-trip green); ready to plan Phase 4
progress:
  total_phases: 8
  completed_phases: 3
  total_plans: 16
  completed_plans: 15
  percent: 50
---

# State

## Current Position

Phase: 4
Plan: Not started
Status: Ready to plan
Last activity: 2026-05-10 -- Phase 3 verified on live cluster; all 5 reference questions round-trip green

### Phase 1 outstanding (carried forward)

Phase 1 code shipped 2026-05-07 with all static checks green. Live-cluster verification still pending — see `.planning/phases/01-cluster-bootstrap-runner-skeleton/01-SUMMARY.md` for the 10-minute on-CP-node procedure (`cka-sim bootstrap` once, re-run for idempotency, `cka-sim doctor` exits 0).

### Outstanding verification (requires user to run on CP node)

1. `cka-sim bootstrap` on a clean CP — expect all green; ssh-copy-id may prompt for password once per worker
2. Re-run `cka-sim bootstrap` — expect no duplicate sentinel blocks in ~/.bashrc or ~/.ssh/config
3. `cka-sim doctor` — expect exit 0 (all 8 checks green)

See `.planning/phases/01-cluster-bootstrap-runner-skeleton/01-SUMMARY.md` for the full 10-minute verification procedure.

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

### Blockers

None.

### Pending Todos

None.

---
*Reset for milestone v1.0 on 2026-05-07.*
