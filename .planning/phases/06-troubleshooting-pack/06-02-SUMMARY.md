---
phase: 06-troubleshooting-pack
plan: 02
subsystem: trap-catalog
tags: [trap-catalog, phase-06, troubleshooting, cka-sim]

requires:
  - phase: 02-trap-framework-assertion-library
    provides: 8-field trap catalog schema and lint-traps.sh validator
  - phase: 06-troubleshooting-pack
    provides: RESEARCH section 3 canonical trap ID table
provides:
  - 11 registered Phase 6 trap IDs for downstream troubleshooting question metadata
  - Append-only catalog delta with structured k8s-doc references
affects: [06-troubleshooting-pack, troubleshooting-question-authoring, lint-packs-pass-e]

tech-stack:
  added: []
  patterns: [append-only YAML trap catalog entries, structured references list]

key-files:
  created:
    - .planning/phases/06-troubleshooting-pack/06-02-SUMMARY.md
  modified:
    - cka-sim/traps/catalog.yaml

key-decisions:
  - "Used RESEARCH §3 trap IDs verbatim and appended only, preserving existing catalog entries."
  - "Applied D-16 severity split: 6 root-cause errors and 5 command-hygiene or secondary warnings."

patterns-established:
  - "Phase 6 trap entries use source community and at least one k8s-doc structured reference."

requirements-completed: [PACK-05, PACK-06]

duration: 22min
completed: 2026-05-13
---

# Phase 06 Plan 02: Troubleshooting Trap Catalog Summary

**Troubleshooting trap catalog expanded with 11 Phase 6 root-cause IDs for downstream metadata validation**

## Performance

- **Duration:** 22 min
- **Started:** 2026-05-13T00:00:00Z
- **Completed:** 2026-05-13T00:22:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Appended 11 new trap entries to `cka-sim/traps/catalog.yaml`.
- Preserved existing catalog entries append-only; diff shows 11 added id lines and 0 removed id lines.
- Verified schema with `bash cka-sim/scripts/lint-traps.sh`.
- Verified zero duplicate trap IDs across full catalog.

## New Trap IDs

| ID | Severity | Domain | Consuming plan |
|---|---|---|---|
| `imagepullbackoff-wrong-tag` | warn | troubleshooting | P03 / Q1 retrofit |
| `netpol-label-key-drift` | error | services-networking | P04 / Q2 |
| `netpol-default-deny-missing-allow` | error | services-networking | P04 / Q2 |
| `coredns-sandbox-configmap-mount` | warn | services-networking | P05 / Q3 |
| `dnsconfig-policy-none-no-nameservers` | error | services-networking | P05 / Q3 |
| `debug-pod-leaked-not-cleaned` | warn | troubleshooting | P06 / Q4 |
| `debug-node-missing-chroot-host` | error | troubleshooting | P06 / Q4 |
| `debug-ephemeral-vs-node-confusion` | warn | troubleshooting | P06 / Q4 |
| `static-pod-manifest-bad-yaml` | error | troubleshooting | P07 / Q5 |
| `static-pod-image-tag-typo` | warn | troubleshooting | P07 / Q5 |
| `kubelet-flag-file-malformed-quoting` | error | cluster-architecture | P08 / Q6 |

## Delta Confirmation

| Check | Result |
|---|---:|
| Pre-append count | 36 |
| Post-append count | 47 |
| Delta | 11 |
| Added `+  - id:` lines | 11 |
| Removed `-  - id:` lines | 0 |
| Duplicate IDs | 0 |

## Severity Split

- **warn:** 5 (`imagepullbackoff-wrong-tag`, `coredns-sandbox-configmap-mount`, `debug-pod-leaked-not-cleaned`, `debug-ephemeral-vs-node-confusion`, `static-pod-image-tag-typo`)
- **error:** 6 (`netpol-label-key-drift`, `netpol-default-deny-missing-allow`, `dnsconfig-policy-none-no-nameservers`, `debug-node-missing-chroot-host`, `static-pod-manifest-bad-yaml`, `kubelet-flag-file-malformed-quoting`)

## Task Commits

1. **Task 1: Append 11 trap entries to traps/catalog.yaml** - `82ce208` (feat)

## Files Created/Modified

- `cka-sim/traps/catalog.yaml` - Appended 11 Phase 6 trap entries with all 8 fields and structured references.
- `.planning/phases/06-troubleshooting-pack/06-02-SUMMARY.md` - This execution summary.

## Verification

- `bash cka-sim/scripts/lint-traps.sh` - PASS, 47 entries schema OK.
- Delta check `post - pre == 11` - PASS.
- Duplicate check `awk '/^- id:/{print $3}' ... | sort | uniq -d` equivalent for two-space catalog form - PASS, empty.
- Full suite `bash cka-sim/scripts/test.sh` - FAIL due pre-existing out-of-scope lint error in `cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh` containing banned `kubectl get | grep`; trap catalog lint passed before failure.

## Decisions Made

- Followed RESEARCH §3 exact ID order and field values.
- Used `source: community` for all 11 entries as planned.
- Used `k8s-doc` references only, one per entry, with canonical plan-specified targets.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Full `bash cka-sim/scripts/test.sh` stopped in lint-packs pass A on pre-existing `cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh` banned `kubectl get | grep`. This was outside this plan's modified files and not fixed.

## Known Stubs

None found in files modified by this plan.

## Threat Flags

None. No new endpoint, auth path, file access pattern, or trust-boundary schema change introduced.

## Self-Check: PASSED

- Found modified file: `cka-sim/traps/catalog.yaml`
- Found summary file: `.planning/phases/06-troubleshooting-pack/06-02-SUMMARY.md`
- Found task commit: `82ce208`
- Confirmed pre/post/delta: `36 -> 47`, delta `11`

## Next Phase Readiness

Downstream Phase 6 plans P03-P08 can reference the 11 new trap IDs in `metadata.yaml.traps[]` without failing trap catalog registration.

---
*Phase: 06-troubleshooting-pack*
*Completed: 2026-05-13*
