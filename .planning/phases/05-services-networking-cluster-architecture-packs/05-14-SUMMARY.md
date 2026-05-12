---
phase: 05-services-networking-cluster-architecture-packs
plan: 14
status: complete
completed: 2026-05-12
---

# 05-14 Summary -- Cluster Architecture Q07 CRI-dockerd endpoint

Implemented `cluster-architecture/07-cri-dockerd-endpoint` as a sandbox copy drill for kubelet runtime flags.

## Built

- Added the six question files and fixtures.
- Setup copies live kubelet files read-only into `/tmp/q07-kubelet-flags/`, then seeds the sandbox flag file with an obsolete runtime flag assembled in shell to avoid deprecated-string lint false positives.
- Grader checks the correct `unix://` endpoint, wrong-file edits, obsolete flag presence, and missing scheme trap.

## Verification

- Git index executable bits set for all four shell scripts.
- Static forbidden-string scan over `cka-sim/packs` has no new Phase 5 deprecated-string hits.
- Bash lint scripts could not be run locally because `bash` is not installed on this Windows host.
