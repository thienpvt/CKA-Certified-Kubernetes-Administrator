---
phase: 04-storage-workloads-scheduling-packs
plan: 02
subsystem: cka-sim
tags: [trap-catalog, fixtures, storage, workloads-scheduling]
requires:
  - cka-sim/traps/catalog.yaml (13 pre-existing entries, 8 seeded)
  - cka-sim/scripts/lint-traps.sh (schema + enum + RFC 1123 + reference-path lint)
  - cka-sim/tests/fixtures/ (Phase 2 hit/miss/benign convention)
provides:
  - 7 new trap-catalog IDs available for Wave 3 per-question plans to reference
  - 21 fixture files (hit/miss/benign per new trap) ready for detector unit tests
affects:
  - Wave 3 plans (04-10 through 04-16) can now register trap IDs in metadata.yaml
  - Plan 04-14 (DaemonSet Q05) gains a genuinely-applicable third trap
tech-stack:
  added: []
  patterns:
    - "append-only catalog edit (no existing entries modified)"
    - "3-fixture pattern (hit/miss/benign) continuing Phase 2 convention"
key-files:
  created:
    - cka-sim/tests/fixtures/csi-snapshot-wrong-driver/{hit,miss,benign}.json
    - cka-sim/tests/fixtures/pvc-pending-wffc-unscheduled-consumer/{hit,miss,benign}.json
    - cka-sim/tests/fixtures/reclaim-policy-delete-data-loss/{hit,miss,benign}.json
    - cka-sim/tests/fixtures/pvc-accessmode-rwx-on-rwo-sc/{hit,miss,benign}.json
    - cka-sim/tests/fixtures/hpa-missing-metrics-server/{hit,miss,benign}.json
    - cka-sim/tests/fixtures/sidecar-not-native-restartpolicy-always/{hit,miss,benign}.json
    - cka-sim/tests/fixtures/daemonset-missing-control-plane-toleration/{hit,miss,benign}.json
  modified:
    - cka-sim/traps/catalog.yaml (appended 7 entries; pre-existing 13 untouched)
decisions:
  - "Append order locked per CONTEXT §Authoring + revision addendum: storage 4 first, then workloads-scheduling 3"
  - "7th trap (daemonset-missing-control-plane-toleration) added during plan-checker revision (W3) so Plan 04-14 has a genuinely-applicable third trap; sidecar-not-native-restartpolicy-always does not fit DaemonSet shape"
  - "Fixtures remain minimal JSON — only fields the detector reads; Phase 2 convention preserved"
  - "No detector functions added to lib/traps.sh in this plan; detectors land with their owning question in Wave 3"
metrics:
  duration: "~15 minutes"
  completed: 2026-05-10
  tasks-completed: 2
  files-created: 21
  files-modified: 1
  commits: 2
---

# Phase 4 Plan 02: Trap Catalog + Fixtures Summary

Ship 7 new trap IDs and 21 matching fixtures so Wave 3 per-question plans can register traps and write detector tests without scaffolding.

## What Shipped

### Catalog Extensions (cka-sim/traps/catalog.yaml)

7 new entries appended after `rbac-viewer-role-mismatch`, in the locked order:

| # | ID | Domain | Severity | Source |
|---|----|--------|----------|--------|
| 1 | csi-snapshot-wrong-driver | storage | error | community |
| 2 | pvc-pending-wffc-unscheduled-consumer | storage | warn | community |
| 3 | reclaim-policy-delete-data-loss | storage | warn | community |
| 4 | pvc-accessmode-rwx-on-rwo-sc | storage | warn | community |
| 5 | hpa-missing-metrics-server | workloads-scheduling | error | concerns-md |
| 6 | sidecar-not-native-restartpolicy-always | workloads-scheduling | warn | concerns-md |
| 7 | daemonset-missing-control-plane-toleration | workloads-scheduling | warn | community |

Domain split: 4 storage + 3 workloads-scheduling. Total catalog size: 13 → 20.

### Fixtures (cka-sim/tests/fixtures/)

7 directories, 3 files each (hit / miss / benign) = 21 JSON files. Each file is a minimal Kubernetes resource object shaped as `kubectl get -o json` would return — only fields the corresponding detector needs to read.

- **hit.json** — resource exhibits the trap condition; detector must fire.
- **miss.json** — same kind / namespace as hit, but trap condition absent; detector must not fire.
- **benign.json** — typically a different resource kind; detector must skip and not false-positive.

## Verification

- `bash cka-sim/scripts/lint-traps.sh` → green on all 20 entries (schema + enum + RFC 1123 + CONCERNS.md reference-path all pass).
- `grep -c '^  - id:' cka-sim/traps/catalog.yaml` → 20 (was 13, +7).
- Last 7 IDs in catalog match the locked order exactly.
- `git diff cka-sim/traps/catalog.yaml | grep '^-' | grep -v '^---' | wc -l` → 0 (append-only; no existing entries modified).
- `python -c 'json.load(open(f))'` → all 21 fixtures parse cleanly.
- Structural greps on each hit.json pass (readyToUse=false + error, persistentVolumeReclaimPolicy=Delete + claimRef, ReadWriteMany + manual SC, FailedGetResourceMetric, log-tailer-without-initContainers, DaemonSet-without-control-plane-toleration).
- `bash cka-sim/scripts/test.sh` → 23/23 cases pass. No regression.

## Deviations from Plan

None — plan executed exactly as written. The 7-entry append (not the original 6) is the plan's documented state after the W3 revision; the `daemonset-missing-control-plane-toleration` entry is specified verbatim in the plan action block.

## Note for Orchestrator

RESEARCH §3 originally spec'd 6 entries. The 7th (`daemonset-missing-control-plane-toleration`) was added during plan-checker revision. If documentation consistency matters, backfill RESEARCH.md §3 with this entry's spec; otherwise the plan + SUMMARY already carry it.

## Self-Check: PASSED

- cka-sim/traps/catalog.yaml — FOUND (20 entries, lint green)
- 21 fixture files — FOUND (all valid JSON, structural greps pass)
- Commit 4d6a930 (feat: catalog) — FOUND in git log
- Commit 692f677 (test: fixtures) — FOUND in git log
- bash cka-sim/scripts/test.sh → 23/23 green
