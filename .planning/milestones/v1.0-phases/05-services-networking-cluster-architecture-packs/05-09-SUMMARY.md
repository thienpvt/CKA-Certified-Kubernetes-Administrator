---
phase: 05-services-networking-cluster-architecture-packs
plan: 09
status: complete
completed: 2026-05-12
---

# 05-09 Summary -- Cluster Architecture Q02 etcd backup restore

Implemented `cluster-architecture/02-etcd-backup-restore` as a sandboxed etcd snapshot and restore drill.

## Built

- Added setup, grade, reset, ref-solution, metadata, and question files.
- Grader checks snapshot presence, `etcdutl snapshot status`, restored WAL directory, v3 API usage, and safe restore data-dir.
- Added manifest, coverage, README, and fixture wiring.

## Verification

- Git index executable bits set for all four shell scripts.
- Static forbidden-string scan over `cka-sim/packs` has no new Phase 5 deprecated-string hits.
- Bash lint scripts could not be run locally because `bash` is not installed on this Windows host.
