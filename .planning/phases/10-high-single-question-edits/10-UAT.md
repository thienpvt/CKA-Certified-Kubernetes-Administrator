---
status: complete
phase: 10-high-single-question-edits
source:
  - 10-01-SUMMARY.md (BUG-H01 storage/01-pvc-binding)
  - 10-02-SUMMARY.md (BUG-H02 services-networking/05-kube-proxy-mode)
  - 10-03-SUMMARY.md (BUG-H03 cluster-architecture/04-pss-enforce)
  - 10-04-SUMMARY.md (BUG-H04 cluster-architecture/08-priorityclass)
started: 2026-05-18T13:56:00Z
updated: 2026-05-18T15:00:16Z
context: |
  Live drills run on the v1.0.1 lab cluster via
  `bash cka-sim/scripts/uat-phase10.sh` from the CP node.
  Driver script ran 12 sub-checks across 4 BUGs.
runner: cka-sim/scripts/uat-phase10.sh
runner_result: "12 passed, 0 failed, 0 skipped (of 12)"
---

## Current Test

[testing complete]

## Tests

### 1. BUG-H01 — storage/01-pvc-binding live drill
expected: |
  H01.1 question.md symptom claim points at Pod scheduling (not PVC stuck Pending)
  H01.2 empty submission scores 0/3 with hostpath-pv trap
  H01.3 ref-solution scores 3/3 with 0 traps
result: pass
runner_subtests: 3/3

### 2. BUG-H02 — services-networking/05-kube-proxy-mode live drill
expected: |
  H02.1 setup seeds SEED_MODE='placeholder' to /tmp/q05-kube-proxy/.setup-seeded-mode
  H02.2 empty submission scores 0/3
  H02.3 ref-solution scores 3/3 on this cluster's proxy mode (previously-broken ipvs path)
result: pass
runner_subtests: 3/3

### 3. BUG-H03 — cluster-architecture/04-pss-enforce live drill
expected: |
  H03.1 ref-solution.sh has no live kubectl apply for candidate Pod
  H03.2 empty submission scores 0/5 with 2 traps
  H03.3 ref-solution scores 5/5 with 0 traps
result: pass
runner_subtests: 3/3

### 4. BUG-H04 — cluster-architecture/08-priorityclass live drill
expected: |
  H04.1 empty submission scores 0/2 with priorityclass trap
  H04.2 flip q08-critical scores 2/2 (preserved path)
  H04.3 flip q08-batch scores 2/2 (BUG-H04 success criterion #4 — previously broken)
result: pass
runner_subtests: 3/3

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

runner_total: 12
runner_passed: 12
runner_failed: 0
runner_skipped: 0

## Gaps

[none — all 12 driver-script sub-checks green]
