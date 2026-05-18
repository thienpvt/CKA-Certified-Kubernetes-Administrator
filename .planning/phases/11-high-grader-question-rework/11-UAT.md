---
status: complete
phase: 11-high-grader-question-rework
source:
  - 11-01-SUMMARY.md (BUG-H05 troubleshooting/04-debug-node)
  - 11-02-SUMMARY.md (BUG-H06 troubleshooting/05-static-pod-manifest)
started: 2026-05-18T15:03:00Z
updated: 2026-05-18T15:03:51Z
context: |
  Live drills run on the v1.0.1 lab cluster via
  `bash cka-sim/scripts/uat-phase11.sh` from the CP node.
  Driver script ran 7 sub-checks across 2 BUGs.
runner: cka-sim/scripts/uat-phase11.sh
runner_result: "7 passed, 0 failed, 0 skipped (of 7)"
---

## Current Test

[testing complete]

## Tests

### 1. BUG-H05 — troubleshooting/04-debug-node live drill
expected: |
  H05.1 ref-solution.sh no longer carries the forgeable kubectl.kubernetes.io/debug-source label
  H05.2 question.md authorizes any K8s-native technique + states grader scores answer.txt only
  H05.3 empty submission scores 0/1 with 0 traps (no ephemeral, no debug-source pod)
  H05.4 ref-solution scores 1/1 with 0 traps (label-free hand-rolled privileged Pod path)
result: pass
runner_subtests: 4/4

### 2. BUG-H06 — troubleshooting/05-static-pod-manifest live drill
expected: |
  H06.1 question.md no longer claims kubelet-pickup/Running framing; mentions file-based grading
  H06.2 empty submission (broken tab-indent variant) scores 0/3 with 1 dedup trap
  H06.3 ref-solution overwrites manifest.yaml with valid Pod, scores 3/3 with 0 traps
result: pass
runner_subtests: 3/3

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

runner_total: 7
runner_passed: 7
runner_failed: 0
runner_skipped: 0

## Gaps

[none — all 7 driver-script sub-checks green]
