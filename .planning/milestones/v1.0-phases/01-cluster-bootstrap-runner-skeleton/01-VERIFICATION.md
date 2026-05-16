---
phase: 01
verified: 2026-05-14
status: verified
must_haves_passed: 7
must_haves_total: 7
human_verification_count: 0
score: 7/7 must-haves verified; live CP-node bootstrap, SSH, and doctor checks passed via UAT
gaps: []
requirements_coverage:
  RUN-01: satisfied
  BOOT-01: satisfied
  BOOT-02: satisfied
  BOOT-03: satisfied
  BOOT-04: satisfied
  BOOT-05: satisfied
  BOOT-06: satisfied
  BOOT-07: satisfied
---

# Phase 1 Verification Report

**Phase Goal:** Candidate can run `cka-sim bootstrap` on the control-plane node and end up with passwordless SSH to `node-01`/`node-02`, configured exam environment, state directories, and a green `cka-sim doctor` against the 1+2 kubeadm cluster.

**Status:** verified. Source files and static contracts present; live bootstrap, passwordless SSH, and `cka-sim doctor` all passed via human UAT on the 1+2 cluster (2026-05-14). One blocker found and fixed during UAT — `bin/cka-sim` now resolves the PATH symlink before deriving `CKA_SIM_ROOT`.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Single `cka-sim` router dispatches supported subcommands | VERIFIED | `cka-sim/bin/cka-sim` dispatches help/bootstrap/doctor/list/version/drill/exam/score via `exec`. |
| 2 | Bootstrap writes sentinel-fenced env exports and state dirs | VERIFIED | `bootstrap.sh` calls `ensure_state_dirs` and writes `.bashrc` block with `ETCDCTL_API=3` and `CONTAINER_RUNTIME_ENDPOINT`. |
| 3 | Bootstrap avoids shell aliases and vimrc mutation | VERIFIED | No alias or vimrc writes exist in `bootstrap.sh`; script comment states BOOT-04 exclusions. |
| 4 | Doctor is read-only and aggregates failures | VERIFIED | `doctor.sh` uses `set -uo pipefail`, increments `failures`, and exits after all checks. |
| 5 | `cka-sim bootstrap` succeeds and is idempotent on CP node | VERIFIED | UAT 2026-05-14: two runs completed cleanly; `grep -c '# === cka-sim BEGIN'` = 1 for both `~/.bashrc` and `~/.ssh/config`. |
| 6 | Passwordless SSH works to both workers | VERIFIED | UAT 2026-05-14: `ssh -o BatchMode=yes worker-1/worker-2 hostname` returned hostnames with no prompt. |
| 7 | `cka-sim doctor` exits 0 on healthy 1+2 cluster | VERIFIED | UAT 2026-05-14: `cka-sim doctor` exits 0 after fixing the symlink-resolution blocker in `bin/cka-sim`. |

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
| Live cluster bootstrap | `cka-sim bootstrap` on CP node | PASS (UAT 2026-05-14) |
| Live cluster doctor | `cka-sim doctor` on CP node | PASS (UAT 2026-05-14) |

## Human Verification Required

Completed via `/gsd-verify-work 01` on 2026-05-14 — see `01-HUMAN-UAT.md`. All 3 items passed.

## Gaps Summary

One blocker found during live UAT and fixed inline: `bin/cka-sim` derived `CKA_SIM_ROOT` from `BASH_SOURCE[0]` without resolving the symlink, so `cka-sim doctor` via the `/usr/local/bin/cka-sim` symlink looked for libs under `/usr/local`. Fixed with `readlink -f` (`bin/cka-sim:12`). Re-tested PASS. No remaining gaps.
