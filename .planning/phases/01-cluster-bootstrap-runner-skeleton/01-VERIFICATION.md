---
phase: 01
verified: 2026-05-12
status: human_needed
must_haves_passed: 4
must_haves_total: 7
human_verification_count: 3
score: 4/7 must-haves verified from files; live CP-node bootstrap and doctor checks pending
gaps: []
requirements_coverage:
  RUN-01: satisfied
  BOOT-01: human_needed
  BOOT-02: human_needed
  BOOT-03: human_needed
  BOOT-04: satisfied
  BOOT-05: satisfied
  BOOT-06: satisfied
  BOOT-07: human_needed
---

# Phase 1 Verification Report

**Phase Goal:** Candidate can run `cka-sim bootstrap` on the control-plane node and end up with passwordless SSH to `node-01`/`node-02`, configured exam environment, state directories, and a green `cka-sim doctor` against the 1+2 kubeadm cluster.

**Status:** human_needed. Source files and static contracts are present; final live bootstrap/doctor checks require the candidate control-plane node.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Single `cka-sim` router dispatches supported subcommands | VERIFIED | `cka-sim/bin/cka-sim` dispatches help/bootstrap/doctor/list/version/drill/exam/score via `exec`. |
| 2 | Bootstrap writes sentinel-fenced env exports and state dirs | VERIFIED | `bootstrap.sh` calls `ensure_state_dirs` and writes `.bashrc` block with `ETCDCTL_API=3` and `CONTAINER_RUNTIME_ENDPOINT`. |
| 3 | Bootstrap avoids shell aliases and vimrc mutation | VERIFIED | No alias or vimrc writes exist in `bootstrap.sh`; script comment states BOOT-04 exclusions. |
| 4 | Doctor is read-only and aggregates failures | VERIFIED | `doctor.sh` uses `set -uo pipefail`, increments `failures`, and exits after all checks. |
| 5 | `cka-sim bootstrap` succeeds and is idempotent on CP node | HUMAN | Requires live control-plane node run. |
| 6 | Passwordless SSH works to both workers | HUMAN | Requires `ssh -o BatchMode=yes node-01/node-02 hostname` on live cluster. |
| 7 | `cka-sim doctor` exits 0 on healthy 1+2 cluster | HUMAN | Requires live cluster with kubeconfig, kubectl, jq, etcdctl, crictl, ssh, and worker access. |

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `cka-sim/bin/cka-sim` | PRESENT | Router entrypoint. |
| `cka-sim/lib/colors.sh` | PRESENT | TTY-aware color vars. |
| `cka-sim/lib/log.sh` | PRESENT | Shared logging helpers. |
| `cka-sim/lib/preflight.sh` | PRESENT | Binary, kubeconfig, topology, worker, SSH, and state-dir checks. |
| `cka-sim/lib/fileblock.sh` | PRESENT | Sentinel block writer. |
| `cka-sim/lib/cmd/bootstrap.sh` | PRESENT | Idempotent bootstrap flow. |
| `cka-sim/lib/cmd/doctor.sh` | PRESENT | Read-only health check. |

## Automated Checks

| Check | Command | Result |
|-------|---------|--------|
| File presence | PowerShell `Test-Path` equivalent through file inspection | PASS |
| Router source inspection | Inspect `cka-sim/bin/cka-sim` | PASS |
| Bootstrap source inspection | Inspect `bootstrap.sh` for state dirs, sentinel block, SSH config, pubkey distribution | PASS |
| Doctor source inspection | Inspect `doctor.sh` aggregate failure flow | PASS |
| Bash syntax/lint | `bash -n` / `shellcheck` | NOT RUN: `bash` and `shellcheck` unavailable on this Windows host |
| Live cluster bootstrap | `cka-sim bootstrap` on CP node | HUMAN |
| Live cluster doctor | `cka-sim doctor` on CP node | HUMAN |

## Human Verification Required

Run on the candidate control-plane node after syncing the repo:

```bash
./cka-sim/bin/cka-sim bootstrap
./cka-sim/bin/cka-sim bootstrap
grep -c '# === cka-sim BEGIN' ~/.bashrc
grep -c '# === cka-sim BEGIN' ~/.ssh/config
ssh -o BatchMode=yes node-01 hostname
ssh -o BatchMode=yes node-02 hostname
source ~/.bashrc
cka-sim doctor
```

Expected:

- Both `grep -c` commands print `1`.
- Both SSH commands return hostnames without password prompts.
- `cka-sim doctor` exits `0`.

## Gaps Summary

No code gaps found from local inspection. Live cluster validation remains pending.
