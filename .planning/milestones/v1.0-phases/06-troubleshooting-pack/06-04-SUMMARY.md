---
phase: 06-troubleshooting-pack
plan: 04
subsystem: cka-sim troubleshooting pack
tags: [troubleshooting, networkpolicy, dns, phase-06]
dependency_graph:
  requires: [06-01, 06-02, 06-03]
  provides: [troubleshooting-netpol-dns-egress]
  affects: [cka-sim/packs/troubleshooting, cka-sim/tests/fixtures/phase-06]
tech_stack:
  added: [Kubernetes NetworkPolicy, kubectl exec probes]
  patterns: [inline manifest setup, read-only grader, trap catalog integration]
key_files:
  created:
    - cka-sim/packs/troubleshooting/02-netpol-dns-egress/setup.sh
    - cka-sim/packs/troubleshooting/02-netpol-dns-egress/grade.sh
    - cka-sim/packs/troubleshooting/02-netpol-dns-egress/reset.sh
    - cka-sim/packs/troubleshooting/02-netpol-dns-egress/ref-solution.sh
    - cka-sim/packs/troubleshooting/02-netpol-dns-egress/metadata.yaml
    - cka-sim/packs/troubleshooting/02-netpol-dns-egress/question.md
    - cka-sim/tests/fixtures/phase-06/troubleshooting-02-netpol-dns-egress/stub-responses.json
    - cka-sim/tests/fixtures/phase-06/troubleshooting-02-netpol-dns-egress/expected-fail-score.txt
    - cka-sim/tests/fixtures/phase-06/troubleshooting-02-netpol-dns-egress/expected-pass-score.txt
  modified: []
decisions:
  - Authored NetworkPolicies inline instead of using seed_netpol_skeleton so missing DNS egress remains visible.
  - Kept candidate prompt symptoms-only while metadata and grader carry prior-art and trap detail.
metrics:
  completed_date: 2026-05-13
  tasks_completed: 1
  task_commits: [7fce73b, 22acec3]
---

# Phase 06 Plan 04: Netpol DNS Egress Troubleshooting Summary

Two-stage NetworkPolicy troubleshooting pack with label-key drift plus missing DNS egress, verified by structural checks and exec probes.

## Completed Work

- Created `troubleshooting-netpol-dns-egress` question pack with setup, grade, reset, ref-solution, metadata, and symptoms-only prompt.
- Setup seeds `web`, `api`, `api-svc`, `default-deny-egress`, and broken `allow-web-to-api` without calling `seed_netpol_skeleton`.
- Grader checks 4 structural conditions plus DNS and TCP probes, recording `netpol-label-key-drift`, `netpol-default-deny-missing-allow`, and `missing-dns-egress`.
- Ref solution fixes both stages: corrects `allow-web-to-api` pod selector and adds UDP/TCP 53 allow to kube-dns.
- Fixtures document expected scores: setup-only failure `SCORE: 4/6`; fixed state `SCORE: 6/6`.

## Verification

- `bash -n cka-sim/packs/troubleshooting/02-netpol-dns-egress/{setup,grade,reset,ref-solution}.sh` passed.
- `py -3 -c "import json,sys; json.load(open(sys.argv[1]))" cka-sim/tests/fixtures/phase-06/troubleshooting-02-netpol-dns-egress/stub-responses.json` passed.
- `bash cka-sim/scripts/lint-packs.sh` passed.
- `bash cka-sim/scripts/lint-deprecated-strings.sh` passed.
- `bash cka-sim/scripts/lint-traps.sh` passed.
- `bash cka-sim/scripts/test.sh` passed with `all 33 case(s) passed`.
- Forbidden-command scan found no `systemctl`, `/etc/kubernetes/`, `/var/lib/kubelet/`, kube-system mutation, or hardcoded `node-01`/`node-02` in the new pack.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Python launcher unavailable as `python3` on Windows**
- **Found during:** Task 1 verification
- **Issue:** `python3` was not available, so JSON fixture validation could not run via the exact plan command.
- **Fix:** Used `py -3` fallback for JSON validation; fixture parsed successfully.
- **Files modified:** None
- **Commit:** N/A

**2. [Rule 3 - Blocking] Executable bits not preserved on first commit**
- **Found during:** Task 1 commit verification
- **Issue:** Initial task commit stored scripts as `100644` despite chmod attempt before adding untracked files.
- **Fix:** Ran `git update-index --chmod=+x` after files were tracked and committed mode-only fix.
- **Files modified:** `cka-sim/packs/troubleshooting/02-netpol-dns-egress/*.sh`
- **Commit:** `22acec3`

## Known Stubs

None.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: network-policy-trust-boundary | cka-sim/packs/troubleshooting/02-netpol-dns-egress/setup.sh | New namespaced NetworkPolicy denial and allow surfaces added for troubleshooting exercise. |

## Self-Check: PASSED

- Found all 6 question files.
- Found all 3 fixture files.
- Found task commit `7fce73b`.
- Found executable-bit fix commit `22acec3`.
