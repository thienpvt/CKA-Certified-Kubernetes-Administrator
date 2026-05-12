---
phase: 05-services-networking-cluster-architecture-packs
plan: 15
status: complete
completed: 2026-05-12
---

# 05-15 Summary -- Cluster Architecture Q08 PriorityClass

Implemented `cluster-architecture/08-priorityclass` as a globalDefault conflict drill.

## Built

- Added the six question files and fixtures.
- Setup creates `q08-critical` and attempts the conflicting `q08-batch`, with fallback creation so both resources exist for the no-delete repair scenario.
- Grader verifies both PriorityClasses still exist and exactly one is `globalDefault`.
- Reset deletes both cluster-scoped PriorityClasses.

## Verification

- Git index executable bits set for all four shell scripts.
- Static forbidden-string scan over `cka-sim/packs` has no new Phase 5 deprecated-string hits.
- Bash lint scripts could not be run locally because `bash` is not installed on this Windows host.
