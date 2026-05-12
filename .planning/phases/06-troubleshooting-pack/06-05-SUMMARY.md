---
phase: 06-troubleshooting-pack
plan: 05
subsystem: cka-sim troubleshooting pack
tags: [troubleshooting, coredns, dns, phase-06]
dependency_graph:
  requires: [06-01, 06-02, 06-03]
  provides: [troubleshooting-coredns-resolution]
  affects: [cka-sim/packs/troubleshooting, cka-sim/tests/fixtures/phase-06]
tech_stack:
  added: [Kubernetes ConfigMap, Deployment, Service, Pod, CoreDNS]
  patterns: [lab-namespace-scoped DNS sandbox, kubectl exec nslookup oracle, trap detectors]
key_files:
  created:
    - cka-sim/packs/troubleshooting/03-coredns-resolution/setup.sh
    - cka-sim/packs/troubleshooting/03-coredns-resolution/grade.sh
    - cka-sim/packs/troubleshooting/03-coredns-resolution/reset.sh
    - cka-sim/packs/troubleshooting/03-coredns-resolution/ref-solution.sh
    - cka-sim/packs/troubleshooting/03-coredns-resolution/metadata.yaml
    - cka-sim/packs/troubleshooting/03-coredns-resolution/question.md
    - cka-sim/tests/fixtures/phase-06/troubleshooting-03-coredns-resolution/stub-responses.json
    - cka-sim/tests/fixtures/phase-06/troubleshooting-03-coredns-resolution/expected-fail-score.txt
    - cka-sim/tests/fixtures/phase-06/troubleshooting-03-coredns-resolution/expected-pass-score.txt
  modified: []
decisions:
  - Lab CoreDNS runs only in question namespace; no kube-system mutation.
  - Corefile omits kubernetes plugin to avoid cluster-scoped RBAC.
  - Grader score remains 5/6 pre-fix and records traps separately.
metrics:
  completed_date: 2026-05-13
  tasks_completed: 1
  files_created: 9
  commits: [d617e27]
---

# Phase 06 Plan 05: Q03 CoreDNS Resolution Summary

Lab-scoped CoreDNS troubleshooting drill with invalid upstream and wrong Corefile subPath.

## What Changed

- Created `troubleshooting/03-coredns-resolution` question files.
- `setup.sh` seeds namespace-local CoreDNS `ConfigMap`, `Deployment`, `Service`, and `q03-dnsclient` probe Pod.
- `grade.sh` checks four resources, probe `dnsPolicy`, and a `kubectl exec` DNS lookup oracle.
- `ref-solution.sh` re-applies fixed Corefile `forward . /etc/resolv.conf` and correct `subPath: Corefile`.
- Fixture tree records pre-fix `SCORE: 5/6` and post-fix `SCORE: 6/6`.

## Lab Architecture

Q03 uses namespaced CoreDNS resources, not live `kube-system/coredns`. Probe Pod uses `dnsPolicy: None` with `dnsConfig.nameservers` set to lab CoreDNS Service ClusterIP. This keeps D-11 host-safety intact while still making candidate inspect DNS support resources.

Corefile excludes `kubernetes` plugin. Internal name resolution delegates through `forward . /etc/resolv.conf`, avoiding ClusterRoleBinding or cross-namespace service/endpoints reads.

## Two-Stage Fix

1. Replace unreachable TEST-NET-3 upstream `203.0.113.53:53` with `forward . /etc/resolv.conf`.
2. Change Deployment volume mount `subPath` from lowercase `corefile` to capital `Corefile`, matching ConfigMap key.

Both fixes required for pass.

## Verification

Commands run:

- `bash -n cka-sim/packs/troubleshooting/03-coredns-resolution/*.sh`
- `py -3 -c "import json; json.load(open('cka-sim/tests/fixtures/phase-06/troubleshooting-03-coredns-resolution/stub-responses.json'))"`
- `bash cka-sim/scripts/lint-packs.sh`
- `bash cka-sim/scripts/lint-deprecated-strings.sh`
- `bash cka-sim/scripts/lint-traps.sh`
- `bash cka-sim/scripts/test.sh`

Result: `test.sh` completed with `all 33 case(s) passed`.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. New network surface is lab-namespace-scoped and covered by plan threat model T-6-10 through T-6-12.

## Commits

- `d617e27` — `feat(06-05): add troubleshooting coredns resolution question`

## Self-Check: PASSED

Created files exist and task commit exists.
