---
phase: 05-services-networking-cluster-architecture-packs
plan: 13
status: complete
completed: 2026-05-12
---

# 05-13 Summary -- Cluster Architecture Q06 CRD basics

Implemented `cluster-architecture/06-crd-basics` as a minimal namespaced CRD drill.

## Built

- Added the six question files and fixtures.
- Setup seeds only a ConfigMap hint and does not pre-install the CRD.
- Ref-solution installs `q06widgets.cka-sim.io`, waits for Established, and creates a sample CR.
- Reset deletes the cluster-scoped CRD so custom resources cascade.

## Verification

- Git index executable bits set for all four shell scripts.
- Static forbidden-string scan over `cka-sim/packs` has no new Phase 5 deprecated-string hits.
- Bash lint scripts could not be run locally because `bash` is not installed on this Windows host.
