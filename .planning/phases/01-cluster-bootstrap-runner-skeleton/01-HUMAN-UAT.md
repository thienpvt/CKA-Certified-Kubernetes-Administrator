---
status: partial
phase: 01-cluster-bootstrap-runner-skeleton
source:
  - 01-VERIFICATION.md
started: 2026-05-12
updated: 2026-05-12
---

# Phase 1 Human UAT

## Current Test

[testing paused - 3 blocked items outstanding]

## Tests

### 1. Bootstrap idempotency
expected: Running `./cka-sim/bin/cka-sim bootstrap` twice creates no duplicate sentinel blocks in `~/.bashrc` or `~/.ssh/config`.
result: blocked
blocked_by: ssh-prerequisite
reason: "results.txt shows `ssh-copy-id` failed for worker-1; root must first be able to SSH to 10.140.0.13 with a password, or `/root/.ssh/cka_sim_ed25519.pub` must be manually copied to worker authorized_keys. Sentinel counts were 1 for both ~/.bashrc and ~/.ssh/config."
latest: "After `ssh-keyscan -H worker-1 worker-2`, `ssh-copy-id` failed for both `root@10.140.0.13/.14` and `ubuntu@10.140.0.13/.14` with `Permission denied (publickey)`. Bootstrap still stops at worker-1 pubkey distribution."

### 2. Worker SSH
expected: `ssh -o BatchMode=yes node-01 hostname` and `ssh -o BatchMode=yes node-02 hostname` succeed without password prompts.
result: blocked
blocked_by: ssh-prerequisite
reason: "User ran `ssh -o BatchMode=yes node-01 hostname` and `ssh -o BatchMode=yes node-02 hostname`; both failed with `Host key verification failed.`"
latest: "Host keys were added for worker-1 and worker-2. Remaining blocker is no accepted login principal (`root` and `ubuntu` both rejected) to append the pubkey on workers."

### 3. Doctor readiness
expected: `cka-sim doctor` exits `0` on the healthy 1+2 cluster after bootstrap and `source ~/.bashrc`.
result: blocked
blocked_by: ssh-prerequisite
reason: "User ran `source ~/.bashrc`; `cka-sim doctor` was not on PATH, likely because bootstrap stops before symlink installation. `./cka-sim/bin/cka-sim doctor` ran and passed binaries, kubeconfig, API livez, topology, state dirs, SSH key, bashrc sentinel, and ETCDCTL_API, but failed SSH BatchMode for worker-1 and worker-2."
latest: "`cka-sim` is still not on PATH because bootstrap exits before reaching symlink installation after `ssh-copy-id` fails."

## Summary

total: 3
passed: 0
issues: 0
pending: 0
skipped: 0
blocked: 3

## Gaps

None recorded yet.
