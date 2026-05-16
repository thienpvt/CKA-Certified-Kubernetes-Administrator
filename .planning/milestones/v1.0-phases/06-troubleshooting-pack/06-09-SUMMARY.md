---
phase: 06-troubleshooting-pack
plan: 09
subsystem: cka-sim troubleshooting pack
tags: [pack-finalization, coverage-matrix, verification, checkpoint]
dependency_graph:
  requires: [06-01, 06-02, 06-03, 06-04, 06-05, 06-06, 06-07, 06-08]
  provides: [PACK-05 final manifest, PACK-07 troubleshooting coverage, Phase 6 verification report]
  affects: [cka-sim/packs/troubleshooting, .planning/phases/06-troubleshooting-pack]
tech_stack:
  added: [coverage.yaml]
  patterns: [pack manifest, tracker coverage matrix, verification report]
key_files:
  created:
    - cka-sim/packs/troubleshooting/coverage.yaml
    - .planning/phases/06-troubleshooting-pack/06-VERIFICATION.md
    - .planning/phases/06-troubleshooting-pack/06-09-SUMMARY.md
  modified:
    - cka-sim/packs/troubleshooting/manifest.yaml
    - cka-sim/packs/troubleshooting/README.md
decisions:
  - Task 3 live cluster drills remain checkpointed; STATE.md and ROADMAP.md unchanged for orchestrator ownership.
metrics:
  duration: checkpointed after Tasks 1-2
  completed: 2026-05-13
  tasks_completed: 2
  tasks_total: 3
---

# Phase 06 Plan 09: Wave 3 Pack Finalization + VERIFICATION Summary

Final troubleshooting pack root metadata and Phase 6 verification report now exist; live six-drill cluster round-trip remains human-gated.

## Tasks Completed

| Task | Name | Status | Commit | Files |
|------|------|--------|--------|-------|
| 1 | Write troubleshooting manifest, coverage, README | Complete | ef6b92e | `cka-sim/packs/troubleshooting/manifest.yaml`, `coverage.yaml`, `README.md` |
| 2 | Author Phase 6 VERIFICATION.md | Complete | 0982bab | `.planning/phases/06-troubleshooting-pack/06-VERIFICATION.md` |
| 3 | Human live-drill checklist + STATE.md advance | Checkpoint | pending | STATE.md intentionally not modified |

## One-Liner

Troubleshooting pack finalization with six-question manifest, 9-slug Tracker coverage matrix, 7/8 automated verification, and checkpointed live 1+2 cluster drill sign-off.

## Must-Haves Verdict

| Must-Have | Verdict | Evidence |
|-----------|---------|----------|
| 6-question manifest with correct minutes | PASS | `manifest.yaml` lists Q01-Q06, total 53 minutes |
| Coverage maps every troubleshooting Tracker checkbox | PASS | `coverage.yaml` has 9 tracker slugs |
| README has candidate-facing 6-question table and disclaimer | PASS | README table rows 01..06 plus disclaimer |
| `lint-coverage.sh troubleshooting` green | PASS | Verification command exited 0 |
| Full `lint-coverage.sh` green across 5 packs | PASS | Verification command exited 0 |
| `lint-packs.sh` green | PASS | Verification command exited 0 |
| `06-VERIFICATION.md` authored with 8 criteria | PASS | `status: human_needed`, `must_haves_passed: 7`, `must_haves_total: 8` |
| Live 6-drill round-trip | HUMAN | Task 3 checkpoint; not executed by this agent |

## Live-Drill Matrix

| Question | Expected fail state | Expected pass state | Status |
|----------|---------------------|---------------------|--------|
| Q01 deploy-svc-mismatch | fail-with-trap, ImagePullBackOff/service endpoints evidence | pass-with-ref-solution | pending human |
| Q02 netpol-dns-egress | fail-with-trap, label-drift/DNS egress evidence | pass-with-ref-solution | pending human |
| Q03 coredns-resolution | fail-with-trap, lab CoreDNS evidence | pass-with-ref-solution | pending human |
| Q04 debug-node | fail-with-trap, debug-node evidence missing/wrong | pass-with-ref-solution | pending human |
| Q05 static-pod-manifest | fail-with-trap, sandbox manifest invalid | pass-with-ref-solution | pending human |
| Q06 broken-kubelet | fail-with-trap, sandbox kubelet flags invalid | pass-with-ref-solution | pending human |

## Post-Drill Host-Safety Invariants

| Invariant | Expected | Status |
|-----------|----------|--------|
| kube-system CoreDNS ConfigMap | no diff from baseline | pending human |
| debug pods | none after reset | pending human |
| `/etc/kubernetes/manifests/` listing | no diff from baseline | pending human |
| `/var/lib/kubelet/kubeadm-flags.env` | sha256 matches baseline | pending human |

## Verification Run

- `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-coverage.sh troubleshooting && bash cka-sim/scripts/lint-coverage.sh && bash cka-sim/scripts/test.sh` passed for Task 1.
- `bash cka-sim/scripts/lint-traps.sh`, `lint-packs.sh`, `lint-coverage.sh`, `lint-deprecated-strings.sh`, and `test.sh` passed for Task 2.
- Forbidden command scan for `06-VERIFICATION.md` passed after rewording prose examples so docs contain no forbidden command strings.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Critical verification hygiene] Avoided forbidden command literals in VERIFICATION.md prose**
- **Found during:** Task 2 verification
- **Issue:** Grep-confirm acceptance rejected forbidden command strings present as documentation examples.
- **Fix:** Reworded prose to describe guard scope without spelling blocked command literals.
- **Files modified:** `.planning/phases/06-troubleshooting-pack/06-VERIFICATION.md`
- **Commit:** 0982bab

## Known Stubs

None.

## Threat Flags

None.

## Deferred Items

- WR-01 (Phase 4): full vendoring of CSI + metrics-server manifests under `cka-sim/vendor/` with recorded SHA256.
- IN-04 (Phase 4): `cka_sim::grade::assert_custom` helper + 6-grader retrofit.
- DF-08: Hint reveal, drill mode only.
- Phase 1 live UAT: tracked in `01-HUMAN-UAT.md`; reopen via `/gsd-verify-work 1`.
- Phase 5 live UAT: tracked in `05-VERIFICATION.md`; reopen via `/gsd-verify-work 5`.

## State and Roadmap

Not modified. Orchestrator owns STATE.md and ROADMAP.md writes after all worktree agents in wave complete.

## Self-Check: PASSED

- Created/modified files exist.
- Task commits exist: `ef6b92e`, `0982bab`.
- No STATE.md or ROADMAP.md changes made by this agent.
