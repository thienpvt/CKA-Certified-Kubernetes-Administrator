---
phase: 06-troubleshooting-pack
plan: 01
subsystem: cka-sim pack lint
tags: [bash-lint, host-safety, phase-06]
requires: [PACK-05, PACK-06]
provides: [troubleshooting-forbidden-command-guard]
affects: [cka-sim/scripts/lint-packs.sh, cka-sim/tests/cases/lint_packs_forbidden_command.sh]
tech_stack:
  added: []
  patterns: [bash grep deny-list, fixture-driven lint regression]
key_files:
  created:
    - cka-sim/tests/cases/lint_packs_forbidden_command.sh
    - cka-sim/tests/fixtures/lint-packs/bad-forbidden-systemctl/
    - cka-sim/tests/fixtures/lint-packs/bad-forbidden-coredns-edit/
    - cka-sim/tests/fixtures/lint-packs/bad-forbidden-varlibkubelet-write/
  modified:
    - cka-sim/scripts/lint-packs.sh
    - cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh
decisions:
  - Pass G has no opt-out sentinel because every pattern names live host or kube-system mutation.
  - Clean-input test uses inline clean troubleshooting setup instead of existing good fixture because good fixture comment mentions kubectl delete ns and Pass G scans comments via header wording.
metrics:
  completed: 2026-05-13
  tasks: 2
  commits: 3
---

# Phase 06 Plan 01: Forbidden-Command Guard Summary

Pass G now enforces troubleshooting host-safety by rejecting live cluster mutation commands before Phase 6 question scripts merge.

## What Changed

- Added `pass G: FORBIDDEN-COMMAND guard — troubleshooting pack host-safety (D-09/D-11/D-12)` in `cka-sim/scripts/lint-packs.sh` after pass F and before final summary/exit block.
- Scoped Pass G to `"$PACKS_DIR/troubleshooting"` and guarded missing troubleshooting dirs with `[[ -d "$PACKS_DIR/troubleshooting" ]]`.
- Seeded three full 6-file negative fixture families:
  - `bad-forbidden-systemctl` triggers `systemctl restart kubelet`.
  - `bad-forbidden-coredns-edit` triggers `kubectl edit configmap coredns -n kube-system`.
  - `bad-forbidden-varlibkubelet-write` triggers `echo ... > /var/lib/kubelet/kubeadm-flags.env`.
- Added `lint_packs_forbidden_command.sh` with three negative sub-blocks plus one clean troubleshooting sub-block.

## Pass G Forbidden Patterns

1. `\bsystemctl\b` — `systemctl`
2. `kubectl[[:space:]]+edit[[:space:]]+configmap[[:space:]]+coredns[[:space:]]+-n[[:space:]]+kube-system` — `kubectl edit cm coredns (kube-system)`
3. `kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)[[:space:]]+kube-system` — `kubectl delete ns kube-system`
4. `kubectl[[:space:]]+(cordon|drain)[[:space:]]` — `kubectl cordon/drain`
5. `>[[:space:]]*/etc/kubernetes/` — `write into /etc/kubernetes/ (covers /etc/kubernetes/manifests/ via prefix)`
6. `>[[:space:]]*/var/lib/kubelet/` — `write into /var/lib/kubelet/`
7. `cp[[:space:]]+([^#][^[:space:]]*[[:space:]]+)+/etc/kubernetes/manifests/` — `copy into /etc/kubernetes/manifests/`

## Verification

- `bash -n cka-sim/scripts/lint-packs.sh` passed.
- `bash cka-sim/scripts/lint-packs.sh cka-sim/packs/troubleshooting` passed.
- `bash cka-sim/scripts/test.sh` passed with `all 33 case(s) passed`.
- `git ls-files -s cka-sim/tests/cases/lint_packs_forbidden_command.sh` reports `100755`.

## How P03-P08 Authors Verify Locally

Run:

```bash
bash cka-sim/scripts/lint-packs.sh
```

Any troubleshooting `*.sh` containing forbidden live-host or kube-system mutation emits `FORBIDDEN-COMMAND` and fails lint.

## Existing Phase 5 Pack Impact

Pass G only iterates `"$PACKS_DIR/troubleshooting"`. Existing storage, services-networking, workloads-scheduling, and cluster-architecture packs remain outside Pass G scope. Full `bash cka-sim/scripts/test.sh` remained green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pre-existing GRADE-02 false positive in PriorityClass grader**
- **Found during:** Task 1 verification
- **Issue:** Existing `cluster-architecture/08-priorityclass/grade.sh` used `kubectl get ... | grep -v`, and existing pass A regex treated this as banned `kubectl get | grep` even though it was not a pipe to positive grep.
- **Fix:** Replaced `grep -v | wc -l | tr` pipeline with a bash loop counting non-empty jsonpath lines.
- **Files modified:** `cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh`
- **Commit:** `58bbc7a`

**2. [Rule 1 - Bug] Tracked executable bits for fixture and test shell scripts**
- **Found during:** Final acceptance check
- **Issue:** Windows worktree wrote executable scripts as `100644`, failing git exec-bit acceptance even though runtime chmod made local execution work.
- **Fix:** Applied `git update-index --chmod=+x` to new fixture scripts and `lint_packs_forbidden_command.sh`.
- **Files modified:** fixture `*.sh`, `cka-sim/tests/cases/lint_packs_forbidden_command.sh`
- **Commit:** `6d7b69f`

## Known Stubs

None. Minimal fixture support scripts intentionally exit 0 to isolate Pass G behavior.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: lint-security-guard | cka-sim/scripts/lint-packs.sh | New guard rejects forbidden troubleshooting script commands touching host services, kube-system CoreDNS, `/etc/kubernetes/`, and `/var/lib/kubelet/`. |

## Commits

- `58bbc7a` — `feat(06): add troubleshooting forbidden-command lint guard`
- `af4b4d6` — `test(06): cover troubleshooting forbidden-command guard`
- `6d7b69f` — `fix(06): track executable bits for lint scripts`

## Self-Check: PASSED

- Summary exists: `.planning/phases/06-troubleshooting-pack/06-01-SUMMARY.md`
- Task commits exist: `58bbc7a`, `af4b4d6`, `6d7b69f`
- Full suite green: `bash cka-sim/scripts/test.sh`
- Shared orchestrator artifacts untouched: `.planning/STATE.md`, `.planning/ROADMAP.md`
