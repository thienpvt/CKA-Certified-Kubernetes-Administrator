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

Awaiting candidate control-plane validation.

## Tests

### 1. Bootstrap idempotency
expected: Running `./cka-sim/bin/cka-sim bootstrap` twice creates no duplicate sentinel blocks in `~/.bashrc` or `~/.ssh/config`.
result: pending

### 2. Worker SSH
expected: `ssh -o BatchMode=yes node-01 hostname` and `ssh -o BatchMode=yes node-02 hostname` succeed without password prompts.
result: pending

### 3. Doctor readiness
expected: `cka-sim doctor` exits `0` on the healthy 1+2 cluster after bootstrap and `source ~/.bashrc`.
result: pending

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

None recorded yet.
