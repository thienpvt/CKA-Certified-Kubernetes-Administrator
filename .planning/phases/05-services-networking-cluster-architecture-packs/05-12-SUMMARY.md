---
phase: 05-services-networking-cluster-architecture-packs
plan: 12
status: complete
completed: 2026-05-12
---

# 05-12 Summary -- Cluster Architecture Q05 audit policy

Implemented `cluster-architecture/05-audit-policy` as a sandbox-only audit Policy authoring drill.

## Built

- Added the six question files and fixtures.
- Setup seeds an invalid policy missing a rule level.
- Grader validates `audit.k8s.io/v1` Policy structure using `python3` and records `audit-policy-wrong-stage-verbosity`.

## Verification

- Git index executable bits set for all four shell scripts.
- Static forbidden-string scan over `cka-sim/packs` has no new Phase 5 deprecated-string hits.
- Bash lint scripts could not be run locally because `bash` is not installed on this Windows host.
