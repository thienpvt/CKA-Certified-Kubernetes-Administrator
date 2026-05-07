# State

## Current Position

Phase: 1 complete (Cluster Bootstrap + Runner Skeleton) — **pending user on-cluster verification**
Plan: 01-02-PLAN executed; static checks green
Status: Ready to start Phase 2 (Trap Framework + Assertion Library)
Last activity: 2026-05-07 — Phase 1 code shipped (13 bash files under cka-sim/)

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

### Blockers

None.

### Pending Todos

None.

---
*Reset for milestone v1.0 on 2026-05-07.*
