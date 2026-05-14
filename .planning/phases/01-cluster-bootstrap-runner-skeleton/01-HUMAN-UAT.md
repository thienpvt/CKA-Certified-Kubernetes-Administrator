---
status: complete
phase: 01-cluster-bootstrap-runner-skeleton
source:
  - 01-VERIFICATION.md
started: 2026-05-12
updated: 2026-05-14
---

# Phase 1 Human UAT

## Prerequisites

Passwordless SSH from the control-plane to **both** workers must be working before these tests can run. `cka-sim bootstrap` runs `ssh-copy-id` automatically, but on manually provisioned GCP VMs it usually fails (password SSH disabled).

To unblock: with root console access to each worker, paste `~/.ssh/cka_sim_ed25519.pub` from the control-plane into **root's** `~/.ssh/authorized_keys` on each worker (the login user must match the user you run `cka-sim` as on the control-plane — root↔root). No password-auth changes needed. See cka-sim/README.md → "SSH to Worker Nodes".

Confirm before testing:
```bash
ssh -i ~/.ssh/cka_sim_ed25519 -o BatchMode=yes root@<worker-1-ip> hostname
ssh -i ~/.ssh/cka_sim_ed25519 -o BatchMode=yes root@<worker-2-ip> hostname
```
Both must print a hostname with no prompt.

## Current Test

[testing complete]

## Tests

### 1. Bootstrap idempotency
expected: Running `./cka-sim/bin/cka-sim bootstrap` twice creates no duplicate sentinel blocks in `~/.bashrc` or `~/.ssh/config`.
result: pass
note: "Both runs completed cleanly; `grep -c '# === cka-sim BEGIN'` printed 1 for both ~/.bashrc and ~/.ssh/config. Required `chmod +x cka-sim/bin/cka-sim` first — exec bit was missing from the git index; now fixed via git update-index and README Setup section."

### 2. Worker SSH
expected: `ssh -o BatchMode=yes worker-1 hostname` and `ssh -o BatchMode=yes worker-2 hostname` succeed without password prompts.
result: pass
note: "Both SSH commands returned hostnames (`worker-1`, `worker-2`) with no password or host-key prompt. Node aliases are `worker-1`/`worker-2` (kubectl node names), not `node-01`/`node-02` as the original UAT text said."

### 3. Doctor readiness
expected: `cka-sim doctor` exits `0` on the healthy 1+2 cluster after bootstrap and `source ~/.bashrc`.
result: pass
note: "Initially failed via the PATH symlink (`/usr/local/lib/colors.sh: No such file or directory`, exit 1). Root cause: bin/cka-sim computed CKA_SIM_ROOT from BASH_SOURCE[0] without resolving the symlink. Fixed inline with `readlink -f` (bin/cka-sim:12). Re-tested: `cka-sim doctor` exits 0."

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "`cka-sim doctor` exits 0 when invoked via the PATH symlink after bootstrap"
  status: resolved
  reason: "User reported: `/usr/local/bin/cka-sim: line 15: /usr/local/lib/colors.sh: No such file or directory`, exit 1"
  severity: blocker
  test: 3
  root_cause: "bin/cka-sim:11 computed CKA_SIM_ROOT from dirname of BASH_SOURCE[0] without resolving the symlink; via /usr/local/bin/cka-sim it resolved to /usr/local instead of the repo cka-sim/ dir"
  resolution: "Fixed inline at bin/cka-sim:12 using `readlink -f` to resolve the symlink before deriving CKA_SIM_ROOT. Re-tested: `cka-sim doctor` exits 0."
  artifacts:
    - path: "cka-sim/bin/cka-sim"
      issue: "CKA_SIM_ROOT did not resolve symlinks before computing repo root"
  debug_session: ""
