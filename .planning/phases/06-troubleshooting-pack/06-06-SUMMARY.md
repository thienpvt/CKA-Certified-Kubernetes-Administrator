---
phase: 06-troubleshooting-pack
plan: 06
subsystem: cka-sim troubleshooting pack
tags: [troubleshooting, kubectl-debug-node, phase-06]
dependency_graph:
  requires:
    - .planning/phases/06-troubleshooting-pack/06-CONTEXT.md
    - .planning/phases/06-troubleshooting-pack/06-RESEARCH.md
    - .planning/phases/06-troubleshooting-pack/06-PATTERNS.md
    - cka-sim/lib/setup.sh
    - cka-sim/lib/grade.sh
    - cka-sim/lib/traps.sh
  provides:
    - cka-sim/packs/troubleshooting/04-debug-node/
    - cka-sim/tests/fixtures/phase-06/troubleshooting-04-debug-node/
  affects:
    - cka-sim/packs/troubleshooting
tech_stack:
  added:
    - kubectl debug node exercise pack
    - debug-source label evidence gate
  patterns:
    - sandbox-only setup under /tmp/q04-debug-node
    - read_node_worker dynamic worker discovery
    - read-only grader with trap recording
key_files:
  created:
    - cka-sim/packs/troubleshooting/04-debug-node/setup.sh
    - cka-sim/packs/troubleshooting/04-debug-node/grade.sh
    - cka-sim/packs/troubleshooting/04-debug-node/reset.sh
    - cka-sim/packs/troubleshooting/04-debug-node/ref-solution.sh
    - cka-sim/packs/troubleshooting/04-debug-node/metadata.yaml
    - cka-sim/packs/troubleshooting/04-debug-node/question.md
    - cka-sim/tests/fixtures/phase-06/troubleshooting-04-debug-node/stub-responses.json
    - cka-sim/tests/fixtures/phase-06/troubleshooting-04-debug-node/expected-fail-score.txt
    - cka-sim/tests/fixtures/phase-06/troubleshooting-04-debug-node/expected-pass-score.txt
  modified: []
decisions:
  - D-10 evidence gate requires answer.txt match plus kubectl.kubernetes.io/debug-source pod evidence across Running/Succeeded/Failed phases.
  - ref-solution invokes kubectl debug node/<worker> so fixture round-trip satisfies same evidence gate candidates face.
  - reset.sh owns debug pod cleanup across all namespaces via debug-source label sweep.
metrics:
  duration: not-recorded
  completed_date: 2026-05-13
  tasks_completed: 1
  files_created: 9
---

# Phase 06 Plan 06: Q04 Debug Node Summary

Kubectl node-debug troubleshooting drill now uses Node API kernelVersion oracle gated by debug-source pod evidence, preventing jsonpath-only bypass.

## Completed Work

- Added `troubleshooting/04-debug-node` pack with six standard files.
- Added fixture tree for Q04 with pass/fail score expectations and JSON stub responses.
- Setup seeds only `/tmp/q04-debug-node/` with `.cka-sim-sentinel`, `answer.txt`, and dynamic `worker.txt` from `cka_sim::setup::read_node_worker`.
- Grader compares `/tmp/q04-debug-node/answer.txt` to `kubectl get node <worker> -o jsonpath='{.status.nodeInfo.kernelVersion}'` and requires debug pod evidence.
- Reset deletes any pod labelled `kubectl.kubernetes.io/debug-source` across all namespaces, then removes sentinel-guarded sandbox.

## D-10 Evidence-Gate Oracle

`grade.sh` passes only when both conditions hold:

1. `answer.txt` exactly equals Node API `.status.nodeInfo.kernelVersion` for worker recorded by setup.
2. At least one pod labelled `kubectl.kubernetes.io/debug-source` exists in any namespace and in phase `Running`, `Succeeded`, or `Failed`.

If answer matches but no debug-source evidence exists, grader records `debug-ephemeral-vs-node-confusion` and returns `SCORE: 0/1`.

## Ref-Solution Debug Invocation

`ref-solution.sh` intentionally runs:

```bash
kubectl debug node/<worker> --image=busybox:1.36 -- chroot /host cat /proc/version
```

This creates same debug-source-labelled evidence required from candidates. Leak risk stays bounded because `reset.sh` sweeps debug-source pods across all namespaces.

## Trap Semantics

| Trap | Trigger |
| ---- | ------- |
| `debug-ephemeral-vs-node-confusion` | Correct answer without debug-source evidence. |
| `debug-node-missing-chroot-host` | Lab pod has ephemeral debug annotation while no node-debug evidence exists and answer is wrong. |
| `debug-pod-leaked-not-cleaned` | Debug-source-labelled pod remains Running at grade time. |

## Fixture Scores

- `expected-fail-score.txt`: `SCORE: 0/1`
- `expected-pass-score.txt`: `SCORE: 1/1`

## Verification

Passed:

- `bash -n cka-sim/packs/troubleshooting/04-debug-node/*.sh`
- `python -c "import json,sys; json.load(open(sys.argv[1]))" cka-sim/tests/fixtures/phase-06/troubleshooting-04-debug-node/stub-responses.json`
- `bash cka-sim/scripts/lint-packs.sh`
- `bash cka-sim/scripts/lint-deprecated-strings.sh`
- `bash cka-sim/scripts/lint-traps.sh`
- `bash cka-sim/scripts/test.sh`

Note: `python3` unavailable on Windows shell; `python` JSON load check passed.

## Deviations from Plan

None - plan executed as written.

## Auth Gates

None.

## Known Stubs

None.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: privileged-debug-pod | cka-sim/packs/troubleshooting/04-debug-node/ref-solution.sh | Ref-solution creates a node debug pod; plan threat model T-6-14 covers cleanup through reset.sh sweep. |

## Commits

- `15ea166`: `feat(06-06): add troubleshooting debug node question`

## Self-Check: PASSED

Created files exist and task commit exists.
