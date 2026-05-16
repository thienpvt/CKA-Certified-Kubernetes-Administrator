---
phase: 06-troubleshooting-pack
plan: 08
subsystem: cka-sim troubleshooting pack
tags: [troubleshooting, kubelet, sandbox, phase-06]
dependency_graph:
  requires: [06-01, 06-02, 06-03]
  provides: [troubleshooting-broken-kubelet]
  affects: [cka-sim/packs/troubleshooting, cka-sim/tests/fixtures/phase-06]
tech_stack:
  added: [bash sandbox grader, cka-sim fixtures]
  patterns: [sandbox-only host safety, symptom-only prompt, trap-based grading]
key_files:
  created:
    - cka-sim/packs/troubleshooting/06-broken-kubelet/setup.sh
    - cka-sim/packs/troubleshooting/06-broken-kubelet/grade.sh
    - cka-sim/packs/troubleshooting/06-broken-kubelet/reset.sh
    - cka-sim/packs/troubleshooting/06-broken-kubelet/ref-solution.sh
    - cka-sim/packs/troubleshooting/06-broken-kubelet/metadata.yaml
    - cka-sim/packs/troubleshooting/06-broken-kubelet/question.md
    - cka-sim/tests/fixtures/phase-06/troubleshooting-06-broken-kubelet/stub-responses.json
    - cka-sim/tests/fixtures/phase-06/troubleshooting-06-broken-kubelet/expected-fail-score.txt
    - cka-sim/tests/fixtures/phase-06/troubleshooting-06-broken-kubelet/expected-pass-score.txt
  modified: []
decisions:
  - Used sandbox-only /tmp/q06-kubelet-flags/ and avoided all live host paths or service restarts.
  - Kept candidate prompt symptom-only with node-agent language while allowing required sandbox path and kubeadm-flags.env filename.
metrics:
  duration: not recorded
  completed_date: 2026-05-13
  tasks_completed: 1
  files_changed: 9
---

# Phase 06 Plan 08: Broken Kubelet Troubleshooting Summary

Q06 adds sandbox-only node-agent runtime flag repair drill with four encoded defects and trap-backed grading.

## Completed Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Question files (6) + fixture tree (3) | 8cf1ec9 | cka-sim/packs/troubleshooting/06-broken-kubelet/*, cka-sim/tests/fixtures/phase-06/troubleshooting-06-broken-kubelet/* |

## What Shipped

- Created `cka-sim/packs/troubleshooting/06-broken-kubelet/` with six required question files.
- Created phase-06 fixture tree with `stub-responses.json`, `expected-fail-score.txt`, and `expected-pass-score.txt`.
- Seeded `/tmp/q06-kubelet-flags/kubeadm-flags.env` with four defects:
  1. Removed `--container-runtime=remote` flag.
  2. Bare `--container-runtime-endpoint=/run/cri-dockerd.sock` without `unix://` scheme.
  3. Stray double quote inside `--pod-"infra-container-image=...` causing parse failure.
  4. Companion `kubelet.conf` placeholder containing runtime endpoint reference.
- Added grader assertions for file presence, bash parseability, and canonical `unix:///run/cri-dockerd.sock` endpoint.
- Added trap recording for `removed-container-runtime-flag`, `cri-endpoint-unix-prefix-missing`, `kubelet-runtime-flag-in-kubeconfig`, and `kubelet-flag-file-malformed-quoting`.

## Safety Properties

- Sandbox path is `/tmp/q06-kubelet-flags/`, distinct from Phase 5 Q07 `/tmp/q07-kubelet-flags/`.
- `setup.sh` generates sandbox content from scratch and never reads or writes live node paths.
- `reset.sh` only removes `/tmp/q06-kubelet-flags/` when `.cka-sim-sentinel` exists.
- No Q06 script invokes `systemctl`.
- No Q06 script writes to `/var/lib/kubelet/` or `/etc/kubernetes/`.

## D-04 Prompt Language

`question.md` uses symptom-only terms: node-agent, node-level runtime configuration, runtime endpoint, and companion placeholder. Bare forbidden tokens are absent from candidate prose after stripping the permitted `/tmp/q06-kubelet-flags/...` path and `kubeadm-flags.env` filename.

## Fixture Scores

- Pre-fix expected score: `SCORE: 1/3`.
- Post-fix expected score: `SCORE: 3/3`.

## Verification

Passed:

- `bash -n` over Q06 `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`.
- `python -c "import json; json.load(open('cka-sim/tests/fixtures/phase-06/troubleshooting-06-broken-kubelet/stub-responses.json'))"`.
- D-04 sed-strip forbidden-token check for `question.md`.
- `bash cka-sim/scripts/lint-packs.sh`.
- `bash cka-sim/scripts/lint-deprecated-strings.sh`.
- `bash cka-sim/scripts/lint-traps.sh`.
- `bash cka-sim/scripts/test.sh` (`all 33 case(s) passed`).

Not run successfully:

- Direct focused setup/grade/reset smoke outside fixture runner, because `kubectl` was not available on PATH in this worktree shell. Full suite runner passed without needing live kubectl.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Critical safety] Scrubbed live path mention from seeded placeholder**
- **Found during:** Task 1
- **Issue:** Plan interface text requested a companion placeholder line naming the live node flag path. That would trip the plan's own acceptance criterion forbidding `/var/lib/kubelet/` references in `setup.sh`.
- **Fix:** Wrote equivalent placeholder prose using `node-agent flag file` instead of live path while preserving runtime-endpoint trap behavior.
- **Files modified:** `cka-sim/packs/troubleshooting/06-broken-kubelet/setup.sh`
- **Commit:** `8cf1ec9`

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

Created files exist, task commit exists, and summary file is present.
